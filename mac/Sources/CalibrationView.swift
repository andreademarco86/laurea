import Charts
import SwiftUI

struct CalibrationView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model
        let cal = model.calibration
        Form {
            Section {
                Picker("Level", selection: $model.calibrationLevel) {
                    ForEach(Level.allCases) { Text($0.label).tag($0) }
                }
                .pickerStyle(.segmented)
                .onChange(of: model.calibrationLevel) { Task { await model.loadCalibration() } }
            } footer: {
                Text("BSc, MSc and PhD are calibrated separately, because the standard expected at each level differs.")
                    .font(.caption).foregroundStyle(.secondary)
            }

            Section {
                if let cal, cal.n > 0 {
                    Chart {
                        ForEach(CRITERIA, id: \.key) { s in
                            let v = cal.offsets[s.key] ?? 0
                            BarMark(x: .value("Offset", v), y: .value("Criterion", "(\(s.key)) \(s.name)"))
                                .foregroundStyle(v >= 0 ? Color.green.gradient : Color.red.gradient)
                                .annotation(position: v >= 0 ? .trailing : .leading) {
                                    Text(Fmt.signed(v, digits: 1)).font(.caption).monospacedDigit().foregroundStyle(.secondary)
                                }
                        }
                        RuleMark(x: .value("Zero", 0)).foregroundStyle(.secondary)
                    }
                    .chartXScale(domain: -max(3, maxAbs(cal)) ... max(3, maxAbs(cal)))
                    .chartXAxisLabel("Marks Claude adds to its evidence-based mark")
                    .frame(height: 220)
                    .padding(.vertical, 6)
                    LabeledContent("Total offset", value: "\(Fmt.signed(cal.total, digits: 1)) / \(cal.dissertation_max ?? 90)")
                } else {
                    ContentUnavailableView {
                        Label("Nothing Learned Yet", systemImage: "dial.medium")
                    } description: {
                        Text("Examine \(model.calibrationLevel == .msc ? "an" : "a") \(model.calibrationLevel.label) \(model.calibrationLevel.noun.lowercased()), adjust Claude's marks with the slider or per criterion, and save. The difference becomes the offset Claude applies next time.")
                    }
                }
            } header: {
                Text("Learned Offsets")
            } footer: {
                if let cal, cal.n > 0 {
                    Text("Learned from \(cal.n) examination\(cal.n == 1 ? "" : "s"). Offsets stay cautious with few examples and firm up as you examine more. Claude skips an offset when the evidence clearly contradicts it.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }

            if let cal, !cal.entries.isEmpty {
                Section("Your Adjustments") {
                    Chart(cal.entries) { e in
                        BarMark(x: .value("Examination", e.label ?? e.exam_id), y: .value("Adjustment", e.delta))
                            .foregroundStyle(e.delta >= 0 ? Color.green.gradient : Color.red.gradient)
                            .opacity(e.include == false ? 0.3 : 1)
                    }
                    .chartXAxis(.hidden)
                    .chartYAxisLabel("Your total − Claude's")
                    .frame(height: 140)
                    .padding(.vertical, 6)

                    ForEach(cal.entries) { e in
                        HStack(alignment: .firstTextBaseline) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(e.label?.isEmpty == false ? e.label! : e.exam_id).lineLimit(1)
                                Text(e.date + (e.note?.isEmpty == false ? " · " + e.note! : ""))
                                    .font(.caption).foregroundStyle(.secondary).lineLimit(2)
                            }
                            Spacer()
                            Text("\(Fmt.mark(CalEntry.sum(e.proposed))) → \(Fmt.mark(CalEntry.sum(e.final)))")
                                .monospacedDigit().foregroundStyle(.secondary)
                            Text(Fmt.signed(e.delta)).monospacedDigit().frame(width: 36, alignment: .trailing)
                                .foregroundStyle(e.delta > 0 ? Color.green : e.delta < 0 ? Color.red : Color.secondary)
                            Toggle("Use for learning", isOn: Binding(get: { e.include != false },
                                                                    set: { v in Task { await model.setInclude(e.exam_id, v) } }))
                                .labelsHidden()
                                .toggleStyle(.switch)
                                .controlSize(.small)
                                .help("Use this examination when learning your calibration")
                        }
                    }
                }
            }

            Section {
                Button("Open Calibration Notes") { model.openCalibrationNotes() }
                    .buttonStyle(.link)
            } footer: {
                Text("The notes file is what Claude reads to apply your calibration. To add standing rules, use Examiner Skill.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Calibration")
        .navigationSubtitle("How your marks differ from Claude's")
        .task { await model.loadCalibration() }
    }

    func maxAbs(_ c: CalibrationInfo) -> Double { c.offsets.values.map(abs).max() ?? 0 }
}
