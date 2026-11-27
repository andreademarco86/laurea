import Charts
import SwiftUI

struct CalibrationView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model
        let cal = model.calibration
        Form {
            Section {
                Picker("Level", selection: $model.calibrationScope) {
                    ForEach(Level.allCases) { Text($0.label).tag($0.rawValue) }
                    Text("Papers").tag("paper")
                }
                .pickerStyle(.segmented)
                .onChange(of: model.calibrationScope) { Task { await model.loadCalibration() } }
            } footer: {
                Text(model.calibrationScope == "paper"
                     ? "Paper reviews share one calibration across all venues: how far you move the proposed recommendation."
                     : "BSc, MSc and PhD are calibrated separately, because the standard expected at each level differs.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            if model.calibrationScope == "paper" {
                PaperCalibrationSections(info: model.paperCalibration)
            } else {

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
                    .chartXAxisLabel("Marks added to the evidence-based mark")
                    .frame(height: 220)
                    .padding(.vertical, 6)
                    LabeledContent("Total offset", value: "\(Fmt.signed(cal.total, digits: 1)) / \(cal.dissertation_max ?? 90)")
                    if let support = cal.support {
                        DisclosureGroup("Evidence for learned offsets") {
                            ForEach(CRITERIA, id: \.key) { spec in
                                if let item = support[spec.key] {
                                    let summary = item.examples == 0 ? "No eligible examples" : "\(item.agreeing) of \(item.examples) agree"
                                    LabeledContent("(\(spec.key)) \(spec.name)", value: summary)
                                        .font(.caption)
                                        .foregroundStyle(item.ready ? Color.primary : Color.secondary)
                                }
                            }
                        }
                    }
                } else {
                    ContentUnavailableView {
                        Label("Nothing Learned Yet", systemImage: "dial.medium")
                    } description: {
                        Text("Save your marked reports to build a calibration history. An offset needs consistent adjustments across at least three examinations.")
                    }
                }
            } header: {
                Text("Learned Offsets")
            } footer: {
                if let cal, cal.n > 0 {
                    Text("Learned from \(cal.n) included examination\(cal.n == 1 ? "" : "s"). Recent decisions carry more weight. An offset needs at least three agreeing examples and strong agreement overall. The evidence for the current dissertation takes priority.")
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
                    .chartYAxisLabel("Your total − proposed")
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

            }

            Section {
                Button("Open Calibration Notes") { model.openCalibrationNotes() }
                    .buttonStyle(.link)
            } footer: {
                Text("The notes file holds your learned calibration. To add standing rules, use Examining Standards.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Calibration")
        .navigationSubtitle("How your marks differ from the proposals")
        .task { await model.loadCalibration() }
    }

    func maxAbs(_ c: CalibrationInfo) -> Double { c.offsets.values.map(abs).max() ?? 0 }
}

/// One learned tendency for all paper reviews: the share of a venue's scale by which the reviewer moves the proposed
/// recommendation.
struct PaperCalibrationSections: View {
    @Environment(AppModel.self) private var model
    let info: PaperCalibrationInfo?

    var body: some View {
        Section {
            if let info, info.n > 0 {
                LabeledContent("Learned tendency") {
                    Text(info.ready ? "\(info.shift > 0 ? "More favourable" : "Less favourable") by \(Int((abs(info.shift) * 100).rounded()))% of the scale"
                         : "None yet").foregroundStyle(info.ready ? (info.shift > 0 ? Color.green : Color.red) : Color.secondary)
                }
                if info.ready {
                    Text("On a six-option scale, that is about \(Fmt.signed((info.shift * 5).rounded()))  step\(abs((info.shift * 5).rounded()) == 1 ? "" : "s"); on a four-option journal scale, about \(Fmt.signed((info.shift * 3).rounded())).")
                        .font(.caption).foregroundStyle(.secondary)
                }
                LabeledContent("Reviews moved the same way", value: "\(info.agreeing) of \(info.n)")
            } else {
                ContentUnavailableView {
                    Label("Nothing Learned Yet", systemImage: "dial.medium")
                } description: {
                    Text("Save your paper reviews to build a calibration history. A tendency needs at least three reviews in which you moved the recommendation the same way.")
                }
            }
        } header: {
            Text("Learned Tendency")
        } footer: {
            Text("Recent decisions carry more weight. Laurea applies the tendency only where the evidence leaves room for it, and never to the scores.")
                .font(.caption).foregroundStyle(.secondary)
        }

        if let info, !info.entries.isEmpty {
            Section("Your Reviews") {
                ForEach(info.entries) { e in
                    HStack(alignment: .firstTextBaseline) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(e.label?.isEmpty == false ? e.label! : e.exam_id).lineLimit(1)
                            Text([e.date, e.venue_name, e.note].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · "))
                                .font(.caption).foregroundStyle(.secondary).lineLimit(2)
                        }
                        Spacer()
                        Text("\(e.proposed ?? "–") → \(e.final_label ?? "–")").font(.caption).foregroundStyle(.secondary).lineLimit(1)
                        let steps = e.steps ?? 0
                        Text(steps == 0 ? "0" : Fmt.signed(Double(steps))).monospacedDigit().frame(width: 30, alignment: .trailing)
                            .foregroundStyle(steps > 0 ? Color.green : steps < 0 ? Color.red : Color.secondary)
                            .help("Steps more (+) or less (−) favourable than proposed")
                        Toggle("Use for learning", isOn: Binding(get: { e.include != false },
                                                                set: { v in Task { await model.setInclude(e.exam_id, v) } }))
                            .labelsHidden().toggleStyle(.switch).controlSize(.small)
                    }
                }
            }
        }
    }
}
