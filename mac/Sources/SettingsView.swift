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
            MarkingSchemeSection(scheme: Binding(
                get: { s.wrappedValue.marking_scheme ?? Scheme.defaults },
                set: { s.wrappedValue.marking_scheme = $0; if Scheme.isValid($0) { scheduleSave() } }))
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
