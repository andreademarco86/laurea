import AppKit
import SwiftUI

private typealias ViewState<Value> = SwiftUI.State<Value>

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
                        Text("\(s.wrappedValue.summary_words ?? 250) words").monospacedDigit()
                            .contentTransition(.numericText(value: Double(s.wrappedValue.summary_words ?? 250)))
                            .animation(.default, value: s.wrappedValue.summary_words)
                        Stepper("Summary length", value: Binding(get: { s.wrappedValue.summary_words ?? 250 },
                                                                 set: { s.wrappedValue.summary_words = $0; scheduleSave() }),
                                in: 50...1000, step: 25)
                            .labelsHidden()
                    }
                }
                if (s.wrappedValue.summary_words ?? 250) != 250 {
                    Button("Restore Default (250 words)") { s.wrappedValue.summary_words = 250; scheduleSave() }
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

/// Select the provider and its report-only API credential.
struct EngineSection: View {
    @Environment(AppModel.self) private var model
    @ViewState private var configuring: Engine?

    var body: some View {
        let active = model.activeEngine
        Section {
            ForEach(Engine.allCases) { engine in
                let status = model.engines?.providers[engine.rawValue]
                let hasKey = model.configuredKeys.contains(engine)
                HStack(spacing: 10) {
                    Button {
                        Task { await model.setEngine(engine) }
                    } label: {
                        Label(engine.label, systemImage: engine == active ? "largecircle.fill.circle" : "circle")
                            .fontWeight(engine == active ? .semibold : .regular)
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(engine == active ? .isSelected : [])
                    Spacer()
                    if status?.installing?.state == "running" || status == nil {
                        ProgressView().controlSize(.small)
                    } else if status?.installed != true {
                        Button(status?.installing?.state == "error" ? "Retry Install" : "Install") {
                            Task { await model.installEngine(engine) }
                        }
                    }
                    if hasKey {
                        Menu("API Key Saved") {
                            Button("Replace API Key…") { configuring = engine }
                            Button("Remove API Key", role: .destructive) { model.removeAPIKey(for: engine) }
                        }
                        .fixedSize()
                    } else {
                        Button("Add API Key…") { configuring = engine }
                    }
                }
            }
            if model.configuredKeys.contains(active) {
                let list = model.models[active.rawValue]?.models ?? []
                let selected = model.settings.model ?? ""
                let efforts = active == .claude ? ["low", "medium", "high"] : ["low", "medium", "high", "xhigh"]
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
                    LabeledContent("Loading API models") { ProgressView().controlSize(.small) }
                } else if let error = model.models[active.rawValue]?.error {
                    Text(error).font(.caption).foregroundStyle(.secondary)
                }
                Picker("Thoroughness", selection: Binding(
                    get: { model.settings.effort ?? "high" },
                    set: { effort in Task { await model.setEngine(active, effort: effort) } })) {
                        ForEach(efforts, id: \.self) { Text(Engine.effortLabel($0)).tag($0) }
                    }
            }
        } header: {
            Text("Examination Engine")
        } footer: {
            Text("Laurea sends report and teaching tasks through the selected provider’s API. API billing and retention apply. Web searches and session history are disabled for these tasks. Your Claude and ChatGPT account settings stay as they are.")
        }
        .sheet(item: $configuring) { PrivateAPIKeyView(engine: $0) }
    }
}

private struct PrivateAPIKeyView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @ViewState private var key = ""
    @ViewState private var confirmed: Bool
    let engine: Engine

    init(engine: Engine) {
        self.engine = engine
        _confirmed = ViewState(wrappedValue: engine == .claude)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("\(engine.label) API Key").font(.headline)
            Text("Use a dedicated API key for Laurea. macOS Keychain stores the key, and API usage is billed by \(engine.company).")
                .foregroundStyle(.secondary)
            SecureField("API key", text: $key)
            HStack {
                Link("Manage API keys", destination: engine.apiKeysURL)
                Spacer()
                Link("Provider data controls", destination: engine.dataControlsURL)
            }
            Toggle(engine == .claude
                   ? "My Anthropic API organisation has not opted into sharing data for model improvement."
                   : "This OpenAI API project has data sharing off and uses Modified Abuse Monitoring or Zero Data Retention.",
                   isOn: $confirmed)
            Text("Verify your provider’s data controls before saving. Laurea relies on your confirmation.")
                .font(.caption).foregroundStyle(.secondary)
            HStack {
                Spacer()
                Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction)
                Button("Save API Key") {
                    if model.saveAPIKey(key, for: engine) { dismiss() }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!confirmed || key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(22)
        .frame(width: 430)
    }
}
