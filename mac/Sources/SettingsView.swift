import AppKit
import SwiftUI

struct SettingsView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model
        let s = $model.settings
        Form {
            Section("Examiner") {
                TextField("Name", text: Binding(get: { s.wrappedValue.examiner_name ?? "" }, set: { s.wrappedValue.examiner_name = $0; scheduleSave() }),
                          prompt: Text("Your name, as it should appear on reports"))
                TextField("Institution", text: Binding(get: { s.wrappedValue.institution ?? "" }, set: { s.wrappedValue.institution = $0; scheduleSave() }),
                          prompt: Text("Your university or institution"))
                TextField("Default degree", text: Binding(get: { s.wrappedValue.degree_default ?? "" }, set: { s.wrappedValue.degree_default = $0; scheduleSave() }),
                          prompt: Text("The degree you examine most often"))
                SignatureField()
            }
            MarkingSchemeSection(scheme: Binding(
                get: { s.wrappedValue.marking_scheme ?? Scheme.defaults },
                set: { s.wrappedValue.marking_scheme = $0; if Scheme.isValid($0) { scheduleSave() } }))
            EngineSection()
            Section("Files") {
                LabeledContent("Examinations") {
                    Button("Show in Finder") { NSWorkspace.shared.open(model.backend.examsDir) }.buttonStyle(.link)
                }
                LabeledContent("Examining standards") {
                    Button("Show in Finder") { NSWorkspace.shared.open(model.backend.skillDir) }.buttonStyle(.link)
                }
                LabeledContent("Calibration notes") {
                    Button("Open") { model.openCalibrationNotes() }.buttonStyle(.link)
                }
                if let u = model.settings.skill_updated {
                    LabeledContent("Skill last updated", value: u)
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 480)
        .fixedSize(horizontal: false, vertical: true)
        .task { await model.loadSettings(); await model.loadEngines() }
    }

    private func scheduleSave() {
        model.settingsSaveTask?.cancel()
        model.settingsSaveTask = Task {
            try? await Task.sleep(for: .milliseconds(600))
            guard !Task.isCancelled else { return }
            await model.saveSettings()
        }
    }
}

/// Criterion weights. Each weight is that criterion's maximum mark; the criteria and the viva add up to 100.
struct MarkingSchemeSection: View {
    @Binding var scheme: [String: Int]

    static let colors: [String: Color] = ["a": .blue, "b": .indigo, "c": .purple, "d": .pink, "e": .orange, "viva": .teal]

    var total: Int { CRITERIA.reduce(0) { $0 + (scheme[$1.key] ?? 0) } + (scheme["viva"] ?? 0) }

    var body: some View {
        Section {
            SchemeBar(scheme: scheme)
                .padding(.vertical, 4)
            ForEach(CRITERIA, id: \.key) { c in
                row(key: c.key, label: "(\(c.key)) \(c.name)", range: 1...60)
            }
            row(key: "viva", label: "Viva", range: 0...40)
            LabeledContent {
                HStack(spacing: 6) {
                    Image(systemName: total == 100 ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                    Text(total == 100 ? "100%" : "\(total)% – must be 100%")
                        .monospacedDigit()
                }
                .foregroundStyle(total == 100 ? Color.green : Color.orange)
                .contentTransition(.numericText(value: Double(total)))
                .animation(.default, value: total)
            } label: {
                Text("Total").fontWeight(.semibold)
            }
            if scheme != Scheme.defaults {
                Button("Restore Default Weights") { scheme = Scheme.defaults }
                    .buttonStyle(.link)
            }
        } header: {
            Text("Marking Scheme")
        } footer: {
            Text("Each weight is that criterion's maximum mark, so the dissertation is marked out of \(100 - (scheme["viva"] ?? 0)) and the viva out of \(scheme["viva"] ?? 0). Changes apply to new examinations; finished reports keep the scheme they were marked with, and your calibration carries over.")
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    private func row(key: String, label: String, range: ClosedRange<Int>) -> some View {
        let value = Binding(get: { scheme[key] ?? 0 }, set: { scheme[key] = min(max($0, range.lowerBound), range.upperBound) })
        return LabeledContent {
            HStack(spacing: 8) {
                Circle().fill(Self.colors[key] ?? .gray).frame(width: 8, height: 8)
                Text("\(value.wrappedValue)%")
                    .monospacedDigit()
                    .frame(minWidth: 40, alignment: .trailing)
                    .contentTransition(.numericText(value: Double(value.wrappedValue)))
                    .animation(.default, value: value.wrappedValue)
                Stepper(label, value: value, in: range).labelsHidden()
            }
        } label: {
            Text(label).lineLimit(1)
        }
    }
}

/// A single proportional bar showing how the 100 marks are shared.
struct SchemeBar: View {
    let scheme: [String: Int]

    var body: some View {
        let keys = CRITERIA.map(\.key) + ["viva"]
        let total = max(1, keys.reduce(0) { $0 + (scheme[$1] ?? 0) })
        GeometryReader { geo in
            HStack(spacing: 2) {
                ForEach(keys, id: \.self) { k in
                    let w = scheme[k] ?? 0
                    if w > 0 {
                        RoundedRectangle(cornerRadius: 3)
                            .fill((MarkingSchemeSection.colors[k] ?? .gray).gradient)
                            .overlay(Text(k == "viva" ? "viva" : k).font(.caption2.weight(.semibold)).foregroundStyle(.white).lineLimit(1).minimumScaleFactor(0.5))
                            .frame(width: max(4, (geo.size.width - CGFloat(keys.count) * 2) * CGFloat(w) / CGFloat(total)))
                    }
                }
            }
            .animation(.spring(duration: 0.35), value: scheme)
        }
        .frame(height: 22)
        .accessibilityLabel("Marking scheme proportions")
    }
}

/// Choose which signed-in engine examines, and with which model and thoroughness.
struct EngineSection: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let active = model.activeEngine
        Section {
            ForEach(Engine.allCases) { e in
                EngineRow(engine: e, isActive: e == active)
            }
            if let status = model.engines?.providers[active.rawValue], status.signed_in {
                let list = model.models[active.rawValue]?.models ?? []
                if model.loadingModels.contains(active.rawValue) && list.isEmpty {
                    LabeledContent("Model") { ProgressView().controlSize(.small) }
                } else if !list.isEmpty {
                    let current = model.currentModel(for: active)
                    Picker("Model", selection: Binding(
                        get: { current?.id ?? "" },
                        set: { id in Task { await model.setEngine(active, model: id) } })) {
                        ForEach(list) { m in
                            Text(m.recommended ? "\(m.name) (recommended)" : m.name).tag(m.id)
                        }
                    }
                    if let efforts = current?.efforts, !efforts.isEmpty {
                        Picker("Thoroughness", selection: Binding(
                            get: { efforts.contains(model.settings.effort ?? "") ? model.settings.effort! : (current?.default_effort ?? efforts.last!) },
                            set: { eff in Task { await model.setEngine(active, model: current?.id, effort: eff) } })) {
                            ForEach(efforts, id: \.self) { Text(Engine.effortLabel($0)).tag($0) }
                        }
                    }
                }
            }
        } header: {
            Text("Examination Engine")
        } footer: {
            Text("Uses your own subscription on this Mac. You can be signed in to both and switch at any time; each examination includes a literature search, reference checks and a high-level originality screen. Web searches never include the student's name or the PDF.")
                .font(.caption).foregroundStyle(.secondary)
        }
    }
}

struct EngineRow: View {
    @Environment(AppModel.self) private var model
    let engine: Engine
    let isActive: Bool

    var body: some View {
        let st = model.engines?.providers[engine.rawValue]
        let account = model.models[engine.rawValue]?.account
        HStack(spacing: 12) {
            Button {
                if st?.signed_in == true { Task { await model.setEngine(engine) } }
            } label: {
                Image(systemName: isActive ? "largecircle.fill.circle" : "circle")
                    .font(.title3)
                    .foregroundStyle(isActive ? Color.accentColor : Color.secondary)
            }
            .buttonStyle(.plain)
            .disabled(st?.signed_in != true)
            .help(st?.signed_in == true ? "Use \(engine.label) for examinations" : "Install and sign in first")
            VStack(alignment: .leading, spacing: 2) {
                Text(engine.label).fontWeight(isActive ? .semibold : .regular)
                Group {
                    if st == nil {
                        Text("Checking…")
                    } else if st?.installing?.state == "running" {
                        Text("Installing \(engine.tool)…")
                    } else if st?.installed != true {
                        Text(st?.installing?.state == "error" ? "Install failed. \(st?.installing?.message ?? "")" : "Not installed")
                    } else if st?.signed_in != true {
                        Text("Not signed in")
                    } else if let email = account?.email {
                        Text([email, account?.plan.map { $0.capitalized }].compactMap { $0 }.joined(separator: " · "))
                    } else {
                        Text("Signed in")
                    }
                }
                .font(.caption).foregroundStyle(.secondary).lineLimit(2)
            }
            Spacer()
            if st?.installing?.state == "running" {
                ProgressView().controlSize(.small)
            } else if st != nil && st?.installed != true {
                Button("Install") { Task { await model.installEngine(engine) } }
            } else if st?.installed == true && st?.signed_in != true {
                Button("Sign In…") { model.signIn(engine) }
            } else if st?.signed_in == true {
                Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
            }
        }
        .contentShape(.rect)
        .onTapGesture { if st?.signed_in == true { Task { await model.setEngine(engine) } } }
    }
}
