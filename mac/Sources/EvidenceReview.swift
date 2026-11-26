import SwiftUI

/// Evidence review inside the criterion sections: each strength and weakness carries its own review mark,
/// and evidence the report does not use sits under "Other evidence" in the same criterion.
enum EvidenceMatch {
    static func normalized(_ s: String) -> String {
        s.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: ". ").union(.whitespacesAndNewlines))
            .split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }

    /// The criterion's findings of one kind, keyed by normalized text.
    static func index(_ findings: [EvidenceFinding], criterion: String, kind: String) -> [String: EvidenceFinding] {
        var out: [String: EvidenceFinding] = [:]
        for f in findings where f.criterion == criterion && f.kind == kind { out[normalized(f.finding)] = out[normalized(f.finding)] ?? f }
        return out
    }
}

/// A small status button in place of the bullet: to review, confirmed or dismissed.
struct ReviewMark: View {
    @Environment(AppModel.self) private var model
    let finding: EvidenceFinding
    let examID: String

    var body: some View {
        let (icon, color, label): (String, Color, String) = switch finding.decision {
        case .pending: ("circle", .secondary, "To review")
        case .confirmed, .corrected: ("checkmark.circle.fill", .green, "Confirmed")
        case .dismissed: ("xmark.circle", .secondary, "Dismissed")
        }
        Menu {
            if finding.decision != .confirmed { Button("Confirm") { review(.confirmed) } }
            if finding.decision != .dismissed { Button("Dismiss") { review(.dismissed) } }
            if finding.decision != .pending { Button("Mark as To Review") { review(.pending) } }
        } label: {
            Image(systemName: icon).foregroundStyle(color)
        }
        .menuStyle(.button)
        .buttonStyle(.borderless)
        .menuIndicator(.hidden)
        .fixedSize()
        .disabled(model.reviewSaving.contains(finding.id))
        .help("\(label). Confirm or dismiss this point; to correct it, edit the text.")
        .accessibilityLabel("Evidence review: \(label)")
    }

    private func review(_ decision: EvidenceDecision) {
        guard model.reviewSaving.insert(finding.id).inserted else { return }
        Task {
            await model.reviewEvidence(finding, examID: examID, decision: decision)
            model.reviewSaving.remove(finding.id)
        }
    }
}

/// Evidence noted during the examination that the report's bullets do not use.
struct OtherEvidence: View {
    let findings: [EvidenceFinding]
    let examID: String

    var body: some View {
        if !findings.isEmpty {
            DisclosureGroup {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(findings) { f in
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            ReviewMark(finding: f, examID: examID)
                            VStack(alignment: .leading, spacing: 3) {
                                Text((f.kind == "strength" ? "Strength: " : "Concern: ") + (f.correction.isEmpty ? f.finding : f.correction))
                                    .font(.callout)
                                    .foregroundStyle(f.decision == .dismissed ? .secondary : .primary)
                                    .textSelection(.enabled)
                                RefChips(text: [f.source, f.finding].joined(separator: " "), highlights: f.pdfHighlights).equatable()
                            }
                        }
                    }
                }
                .padding(.top, 4)
            } label: {
                Text("Other evidence (\(findings.count))").font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}
