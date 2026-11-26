import SwiftUI

struct EvidenceLedger: View {
    @Environment(AppModel.self) private var model
    @State private var expanded = false
    @State private var filter: EvidenceDecision?
    @State private var criterion: String?
    @State private var limit = 12
    @State private var editing: EvidenceFinding?
    @State private var saving: Set<String> = []

    let examID: String
    let findings: [EvidenceFinding]
    let scheme: Scheme

    private var visible: [EvidenceFinding] {
        findings.filter { (filter == nil || $0.decision == filter) && (criterion == nil || $0.criterion == criterion) }
    }

    var body: some View {
        let pending = findings.filter { $0.decision == .pending }.count
        Section {
            DisclosureGroup(isExpanded: $expanded) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Picker("Status", selection: $filter) {
                            Text("All statuses").tag(nil as EvidenceDecision?)
                            ForEach(EvidenceDecision.allCases) { decision in
                                Text(decision.label).tag(Optional(decision))
                            }
                        }
                        Picker("Criterion", selection: $criterion) {
                            Text("All criteria").tag(nil as String?)
                            ForEach(scheme.specs, id: \.key) { spec in
                                Text("(\(spec.key)) \(spec.name)").tag(Optional(spec.key))
                            }
                        }
                    }
                    .controlSize(.small)

                    let matching = visible
                    if matching.isEmpty {
                        Text("No findings match these filters.").font(.callout).foregroundStyle(.secondary)
                    }
                    ForEach(matching.prefix(limit)) { finding in
                        card(finding)
                    }
                    if matching.count > limit {
                        Button("Show more findings") { limit += 12 }.buttonStyle(.link)
                    }
                }
                .padding(.vertical, 8)
            } label: {
                HStack {
                    Label("Evidence ledger", systemImage: "list.bullet.clipboard")
                    Spacer()
                    Text("\(pending) to review · \(findings.count) findings")
                        .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                }
            }
        }
        .onChange(of: filter) { limit = 12 }
        .onChange(of: criterion) { limit = 12 }
        .sheet(item: $editing) { finding in
            EvidenceCorrectionSheet(finding: finding) { correction in
                review(finding, as: .corrected, correction: correction)
            }
        }
    }

    private func card(_ finding: EvidenceFinding) -> some View {
        let isStrength = finding.kind == "strength"
        let spec = scheme.specs.first { $0.key == finding.criterion }
        return VStack(alignment: .leading, spacing: 7) {
            HStack(alignment: .firstTextBaseline) {
                Label(isStrength ? "Strength" : "Concern", systemImage: isStrength ? "plus.circle" : "exclamationmark.circle")
                    .foregroundStyle(isStrength ? Color.teal : Color.orange)
                if let spec {
                    Text("(\(spec.key)) \(spec.name)")
                        .lineLimit(1).foregroundStyle(.secondary).help(spec.name)
                }
                Spacer()
                Text(finding.decision.label)
                    .fontWeight(.semibold)
                    .foregroundStyle(finding.decision == .pending ? Color.secondary : Color.primary)
            }
            .font(.caption)
            Text(finding.correction.isEmpty ? finding.finding : finding.correction)
                .font(.callout).textSelection(.enabled)
            if !finding.source.isEmpty {
                Text(finding.source).font(.caption).foregroundStyle(.secondary)
            }
            RefChips(text: [finding.source, finding.finding, finding.correction].joined(separator: " "),
                     highlights: finding.pdfHighlights).equatable()
            if finding.decision == .corrected {
                DisclosureGroup("Original finding") {
                    Text(finding.finding).font(.caption).foregroundStyle(.secondary).textSelection(.enabled)
                }
                .font(.caption)
            }
            HStack(spacing: 8) {
                if finding.decision == .pending {
                    Button("Confirm") { review(finding, as: .confirmed) }.buttonStyle(.bordered)
                }
                Menu {
                    Button("Correct finding…") { editing = finding }
                    if finding.decision != .dismissed {
                        Button("Dismiss finding") { review(finding, as: .dismissed) }
                    }
                    if finding.decision != .pending {
                        Button("Reset to review") { review(finding, as: .pending) }
                    }
                } label: {
                    Text("Review options")
                }
            }
            .controlSize(.small)
            .disabled(saving.contains(finding.id))
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.4), in: .rect(cornerRadius: 8))
    }

    private func review(_ finding: EvidenceFinding, as decision: EvidenceDecision, correction: String = "") {
        guard saving.insert(finding.id).inserted else { return }
        Task {
            await model.reviewEvidence(finding, examID: examID, decision: decision, correction: correction)
            saving.remove(finding.id)
        }
    }
}

private struct EvidenceCorrectionSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var text: String
    let finding: EvidenceFinding
    let save: (String) -> Void

    init(finding: EvidenceFinding, save: @escaping (String) -> Void) {
        self.finding = finding
        self.save = save
        _text = State(initialValue: finding.correction.isEmpty ? finding.finding : finding.correction)
    }

    var body: some View {
        let correction = text.trimmingCharacters(in: .whitespacesAndNewlines)
        VStack(alignment: .leading, spacing: 12) {
            Text("Correct finding").font(.headline)
            if !finding.source.isEmpty {
                Text(finding.source).font(.caption).foregroundStyle(.secondary)
            }
            TextField("Corrected finding", text: $text, axis: .vertical).lineLimit(3...8)
            HStack {
                Spacer()
                Button("Cancel", role: .cancel) { dismiss() }.keyboardShortcut(.cancelAction)
                Button("Save correction") { save(correction); dismiss() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(correction.isEmpty || correction.count > 2500)
            }
        }
        .padding(20)
        .frame(minWidth: 380)
    }
}
