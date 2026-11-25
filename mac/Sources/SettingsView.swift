import AppKit
import SwiftUI

struct SettingsView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model
        let s = $model.settings
        Form {
            Section("Examiner") {
                TextField("Name", text: Binding(get: { s.wrappedValue.examiner_name ?? "" }, set: { s.wrappedValue.examiner_name = $0; scheduleSave() }))
                TextField("Institution", text: Binding(get: { s.wrappedValue.institution ?? "" }, set: { s.wrappedValue.institution = $0; scheduleSave() }))
                TextField("Default degree", text: Binding(get: { s.wrappedValue.degree_default ?? "" }, set: { s.wrappedValue.degree_default = $0; scheduleSave() }))
                LabeledContent("Signature") {
                    if let img = NSImage(contentsOf: model.backend.signatureURL) {
                        Image(nsImage: img).resizable().scaledToFit().frame(height: 36)
                            .padding(4).background(.white, in: .rect(cornerRadius: 5))
                    }
                }
            }
            Section {
                LabeledContent("Model", value: model.settings.model_label ?? "Opus 5.5")
                LabeledContent("Claude Code", value: model.settings.claude_version ?? "Not found")
            } header: {
                Text("Claude")
            } footer: {
                Text("Examinations run on Claude Opus 5.5 and include a literature search, reference checks and a high-level originality screen. Web searches never include the student's name or the PDF.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section("Files") {
                LabeledContent("Examinations") {
                    Button("Show in Finder") { NSWorkspace.shared.open(model.backend.examsDir) }.buttonStyle(.link)
                }
                LabeledContent("Examiner skill") {
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
        .task { await model.loadSettings() }
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
