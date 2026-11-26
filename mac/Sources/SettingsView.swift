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
            Section {
                LabeledContent("Summary length") {
                    HStack(spacing: 8) {
                        Text("\(s.wrappedValue.summary_words ?? 350) words").monospacedDigit()
                            .contentTransition(.numericText(value: Double(s.wrappedValue.summary_words ?? 350)))
                            .animation(.default, value: s.wrappedValue.summary_words)
                        Stepper("Summary length", value: Binding(get: { s.wrappedValue.summary_words ?? 350 },
                                                                 set: { s.wrappedValue.summary_words = $0; scheduleSave() }),
                                in: 50...1000, step: 25)
                            .labelsHidden()
                    }
                }
                if (s.wrappedValue.summary_words ?? 350) != 350 {
                    Button("Restore Default (350 words)") { s.wrappedValue.summary_words = 350; scheduleSave() }
                        .buttonStyle(.link)
                }
            } header: {
                Text("Report")
            } footer: {
                Text("The maximum length of the report's summary. Applies to new examinations.")
                    .font(.caption).foregroundStyle(.secondary)
            }
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

/// Select which signed-in subscription runs examinations and teaching.
struct EngineSection: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let active = model.activeEngine
        Section {
            ForEach(Engine.allCases) { engine in
                SubscriptionRow(engine: engine, selected: engine == active)
            }
            if model.activeEngineReady {
                let list = model.models[active.rawValue]?.models ?? []
                let selected = model.settings.model ?? ""
                let availableEfforts = list.first { $0.id == selected }?.efforts ?? []
                let defaults = active == .claude ? ["low", "medium", "high"] : ["low", "medium", "high", "xhigh"]
                let efforts = availableEfforts.isEmpty ? defaults : availableEfforts
                if !list.isEmpty {
                    Picker("Model", selection: Binding(
                        get: { selected },
                        set: { id in Task { await model.setEngine(active, model: id) } })) {
                            Text("Engine default").tag("")
                            if !selected.isEmpty && !list.contains(where: { $0.id == selected }) {
                                Text(selected).tag(selected)
                            }
                            ForEach(list) { Text($0.name).tag($0.id) }
                        }
                } else if model.loadingModels.contains(active.rawValue) {
                    LabeledContent("Loading models") { ProgressView().controlSize(.small) }
                } else if let error = model.models[active.rawValue]?.error {
                    Text(error).font(.caption).foregroundStyle(.secondary)
                }
                Picker("Thoroughness", selection: Binding(
                    get: { model.settings.effort ?? Engine.defaultEffort },
                    set: { effort in Task { await model.setEngine(active, effort: effort) } })) {
                        if let current = model.settings.effort, !efforts.contains(current) {
                            Text(Engine.effortLabel(current)).tag(current)
                        }
                        ForEach(efforts, id: \.self) { Text(Engine.effortLabel($0)).tag($0) }
                    }
                Link("\(active.label) data controls", destination: active.dataControlsURL)
            }
        } header: {
            Text("Examination Engine")
        } footer: {
            Text("Reports and teaching use your signed-in subscription and its usage limits. The provider’s training and retention settings apply to the data sent during each run.")
        }
    }
}

private struct SubscriptionRow: View {
    @Environment(AppModel.self) private var model
    let engine: Engine
    let selected: Bool

    var body: some View {
        let status = model.engines?.providers[engine.rawValue]
        let signingIn = status?.sign_in?.state == "running"
        let installed = status?.installed == true
        let ready = status?.signed_in == true
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 10) {
                Button {
                    Task { await model.setEngine(engine) }
                } label: {
                    Label(engine.label, systemImage: selected ? "largecircle.fill.circle" : "circle")
                        .fontWeight(selected ? .semibold : .regular)
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selected ? .isSelected : [])
                Spacer()
                if status?.installing?.state == "running" || status == nil {
                    ProgressView().controlSize(.small)
                } else if !installed {
                    Button(status?.installing?.state == "error" ? "Retry Install" : "Install \(engine.tool)") {
                        Task { await model.installEngine(engine) }
                    }
                } else if signingIn {
                    ProgressView().controlSize(.small)
                    Button("Cancel") { Task { await model.cancelSignIn(engine) } }
                } else if ready {
                    Menu("Subscription Signed In") {
                        Button("Sign Out") { Task { await model.signOut(engine) } }
                            .disabled(model.anyRunning || model.skillBusy)
                    }
                    .fixedSize()
                } else {
                    Button("Sign In…") { Task { await model.signIn(engine) } }
                }
            }
            if signingIn {
                Text("Finish signing in in your browser.").font(.caption).foregroundStyle(.secondary)
            } else if let failure = status?.sign_in, failure.state == "error" {
                Text(failure.message ?? "Sign-in did not complete.").font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}
