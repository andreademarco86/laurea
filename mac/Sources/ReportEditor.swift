import AppKit
import SwiftUI

struct ReportEditor: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let draft = Binding<ReportDraft>(
            get: { model.draft ?? ReportDraft() },
            set: { model.draft = $0; model.dirty = true })
        let d = draft.wrappedValue
        let detail = model.detail
        // Sections below the marks get plain values and are equatable: while a mark changes, only the
        // header and marks redraw; a text section redraws only when its own text changes.
        Form {
            Section { ScoreHeader(draft: d) }
            if let b = model.banner { BannerSection(banner: b) }
            MarksSections(draft: draft)
            DetailsSection(student: d.student, title: d.title, degree: d.degree, institution: d.institution,
                           examiner: d.examiner).equatable()
            SummarySection(summary: d.summary, limit: detail?.summary_words ?? 350).equatable()
            CriteriaSection(criteria: d.criteria.map(CriterionText.init), quotes: detail?.quotes ?? [:]).equatable()
            QuestionSections(questions: d.questions, level: detail?.status.level).equatable()
            CorrectionsSection(substantial: d.substantial, corrections: d.corrections).equatable()
            DeclarationSection(draft: draft)
            ExportSection(blocker: model.exportBlocker)
            if let detail, let panel = detail.panel {
                InternalNotesSection(panel: panel, scheme: detail.markingScheme).equatable()
            }
        }
        .formStyle(.grouped)
        .sensoryFeedback(.success, trigger: model.saveCount)
    }
}

struct DetailsSection: View, Equatable {
    @Environment(AppModel.self) private var model
    let student, title, degree, institution, examiner: String

    static func == (a: Self, b: Self) -> Bool {
        (a.student, a.title, a.degree, a.institution, a.examiner) == (b.student, b.title, b.degree, b.institution, b.examiner)
    }

    var body: some View {
        Section("Details") {
            BufferedField("Student name", key: "student", text: model.draftBinding(\.student))
            BufferedField("Title", key: "title", text: model.draftBinding(\.title), axis: .vertical)
            BufferedField("Degree", key: "degree", text: model.draftBinding(\.degree))
            BufferedField("Institution", key: "institution", text: model.draftBinding(\.institution))
            BufferedField("Examiner", key: "examiner", text: model.draftBinding(\.examiner))
        }
    }
}

struct InternalNotesSection: View, Equatable {
    let panel: PanelFeedback
    let scheme: Scheme

    var body: some View {
        Section {
            DisclosureGroup("Internal notes") {
                PanelReview(panel: panel, scheme: scheme)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 8)
            }
        }
    }
}

struct PanelReview: View {
    let panel: PanelFeedback
    let scheme: Scheme

    private let roles = ["methods", "field", "holistic", "chair"]

    private func title(_ role: String) -> String { role.capitalized }

    private func scores(_ role: String) -> [String: Double] {
        role == "chair" ? panel.chair : panel.examiners[role] ?? [:]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Readers and Chair").font(.subheadline.weight(.semibold))
            Grid(horizontalSpacing: 10, verticalSpacing: 10) {
                GridRow {
                    Text("Criterion").frame(maxWidth: .infinity, alignment: .leading)
                    ForEach(roles, id: \.self) { role in
                        Text(title(role)).fontWeight(role == "chair" ? .semibold : .regular)
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)

                ForEach(scheme.specs, id: \.key) { criterion in
                    GridRow {
                        // Fixed icon slot so (a)-(e) line up whether or not a criterion is flagged.
                        HStack(spacing: 6) {
                            Text("(\(criterion.key))").frame(width: 24, alignment: .leading)
                            Image(systemName: "exclamationmark.circle")
                                .foregroundStyle(.orange)
                                .opacity(panel.low_confidence.contains(criterion.key) ? 1 : 0)
                                .help("Lower confidence: the examiners disagreed")
                        }
                        .help(criterion.name)
                        .accessibilityLabel(panel.low_confidence.contains(criterion.key)
                                            ? "\(criterion.name), lower confidence" : criterion.name)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        ForEach(roles, id: \.self) { role in
                            scoreCell(scores(role)[criterion.key], maximum: criterion.max, role: role,
                                      criterion: criterion.name)
                        }
                    }
                }

                GridRow {
                    Text("Total").frame(maxWidth: .infinity, alignment: .leading)
                    ForEach(roles, id: \.self) { role in
                        let marks = scheme.specs.compactMap { scores(role)[$0.key] }
                        let total = marks.count == scheme.specs.count ? marks.reduce(0, +) : nil
                        scoreCell(total, maximum: scheme.dissertationMax, role: role, criterion: "Total")
                    }
                }
                .fontWeight(.semibold)

                if let overall = panel.overall, !overall.isEmpty {
                    GridRow {
                        Text("Overall grade").frame(maxWidth: .infinity, alignment: .leading)
                        ForEach(roles, id: \.self) { role in
                            Text(overall[role] ?? "").font(.caption.weight(.semibold))
                                .help(role == "chair" ? "" : "\(title(role))'s grade for the dissertation as a whole, given before the criteria")
                        }
                    }
                }
            }

            // One line per examiner and one for the chair; the detailed deliberation stays in the work folder.
            Grid(alignment: .topLeading, horizontalSpacing: 12, verticalSpacing: 6) {
                ForEach(roles, id: \.self) { role in
                    if let note = role == "chair" ? panel.summary : panel.notes[role], !note.isEmpty {
                        GridRow {
                            Text(title(role)).fontWeight(.semibold).frame(width: 64, alignment: .leading)
                            Text(Self.plain(note)).foregroundStyle(.secondary).textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .font(.callout)
                    }
                }
            }
            // Rulings on disputed criteria: the advocate's and critic's cases are kept in the work folder.
            let rulings = scheme.specs.compactMap { spec in panel.decisions[spec.key].map { (spec, $0) } }
            if !rulings.isEmpty {
                Grid(alignment: .topLeading, horizontalSpacing: 12, verticalSpacing: 6) {
                    ForEach(rulings, id: \.0.key) { spec, ruling in
                        GridRow {
                            Text("(\(spec.key))").fontWeight(.semibold).frame(width: 64, alignment: .leading)
                                .help("Disputed: \(spec.name)")
                            Text(Self.plain(ruling)).foregroundStyle(.secondary).textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .font(.callout)
                    }
                }
            }
            Text("Chair scores are shown before calibration. Rulings are for criteria where the readers disagreed.")
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    /// Drops trailing page lists such as " (p. 15, p. 82)"; the notes are a quick read, not citations.
    static func plain(_ note: String) -> String {
        note.replacingOccurrences(of: #"\s*\((?:pp?\.\s*[\divxlc–\-]+(?:,\s*)?)+\)"#, with: "",
                                  options: [.regularExpression, .caseInsensitive])
    }

    @ViewBuilder
    private func scoreCell(_ mark: Double?, maximum: Int, role: String, criterion: String) -> some View {
        if let mark, maximum > 0 {
            VStack(spacing: 2) {
                Text("\(Fmt.mark(mark))/\(maximum)")
                    .fontWeight(role == "chair" ? .semibold : .regular)
                Gauge(value: mark, in: 0...Double(maximum)) { EmptyView() }
                    .gaugeStyle(.accessoryLinearCapacity)
                    .tint(role == "chair" ? Color.accentColor : Color.secondary)
                    .frame(maxWidth: 52)
                    .accessibilityHidden(true)
            }
            .font(.caption.monospacedDigit())
            .accessibilityLabel("\(title(role)), \(criterion), \(Fmt.mark(mark)) out of \(maximum)")
        } else {
            Text("–").font(.caption).foregroundStyle(.secondary)
                .accessibilityLabel("\(title(role)), \(criterion), score unavailable")
        }
    }
}

// MARK: - Marks and calibration

struct MarksSections: View {
    @Environment(AppModel.self) private var model
    @Binding var draft: ReportDraft

    var body: some View {
        let detail = model.detail
        Section("Marks") {
            ForEach(Array(draft.criteria.enumerated()), id: \.element.id) { i, c in
                LabeledContent {
                    HStack(spacing: 10) {
                        Gauge(value: Double(c.mark), in: 0...Double(c.spec.max)) { EmptyView() }
                            .gaugeStyle(.accessoryLinearCapacity)
                            .tint(Gradient(colors: [.blue, .indigo]))
                            .frame(width: 70)
                            .animation(.snappy(duration: 0.18), value: c.mark)
                        // Fixed-width columns keep the bars and numbers aligned across rows.
                        Group {
                            if let p = detail?.proposedMark(c.spec.key) {
                                Text("Proposed \(p)")
                                    .foregroundStyle(p == c.mark ? Color.secondary : Color.orange)
                                    .help(p == c.mark ? "Proposed mark" : "You changed this from the proposed \(p)")
                            } else {
                                Text("")
                            }
                        }
                        .font(.caption.monospacedDigit())
                        .frame(width: 84, alignment: .trailing)
                        ScoreColumns(max: c.spec.max) {
                            Text("\(c.mark)").font(.body.weight(.semibold))
                        } control: {
                            Stepper("Mark", value: Binding(get: { c.mark }, set: { model.setMark(i, $0) }), in: 0...c.spec.max)
                                .labelsHidden()
                        }
                    }
                } label: {
                    Text("(\(c.spec.key)) \(c.spec.name)")
                }
            }
        }

        Section {
            if let pt = model.proposedTotal {
                LabeledContent("Proposed mark") {
                    ScoreColumns(max: draft.dissertationMax) { Text("\(pt)").foregroundStyle(.secondary) }
                }
                LabeledContent("Your adjustment") {
                    let d = draft.total - pt
                    ScoreColumns(unit: "marks") {
                        Text(d == 0 ? "0" : Fmt.signed(Double(d)))
                            .foregroundStyle(d > 0 ? Color.green : d < 0 ? Color.red : Color.secondary)
                    }
                }
            }
            BufferedField("Why you adjusted", key: "note", text: Binding(get: { model.note }, set: { model.note = $0 }),
                          prompt: "Optional, e.g. “credit honest negative results in (d)”", axis: .vertical)
            if let applied = model.detail?.applied {
                let nonZero = CRITERIA.compactMap { s -> String? in
                    guard let v = applied[s.key] ?? nil, v != 0 else { return nil }
                    return "(\(s.key)) \(Fmt.signed(v))"
                }
                if !nonZero.isEmpty {
                    Label("Your learned calibration is already included: \(nonZero.joined(separator: ", "))", systemImage: "dial.medium")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
        } header: {
            Text("Your Adjustment")
        } footer: {
            Text("Change the marks above with their arrows. Laurea learns from changes you make consistently to the same criterion across examinations at the same degree level.")
                .font(.caption).foregroundStyle(.secondary)
        }

        Section("Result") {
            LabeledContent("Dissertation") {
                ScoreColumns(max: draft.dissertationMax) { Text("\(draft.total)").font(.body.weight(.semibold)) }
            }
            LabeledContent("Viva") {
                HStack(spacing: 8) {
                    if draft.vivaText.isEmpty {
                        Text("after the oral").font(.caption).foregroundStyle(.secondary)
                    }
                    ScoreColumns(max: draft.vivaMax) {
                        TextField("Viva", text: $draft.vivaText, prompt: Text("–"))
                            .labelsHidden()
                            .multilineTextAlignment(.trailing)
                            .foregroundStyle(draft.vivaInvalid ? .red : .primary)
                    }
                }
            }
            LabeledContent("Final mark") {
                ScoreColumns(max: 100) {
                    Text(draft.viva.map { Fmt.mark(Double(draft.total) + $0) } ?? "–")
                        .font(.body.weight(.bold))
                        .foregroundStyle(draft.viva == nil ? Color.secondary : Color.accentColor)
                }
            }
        }
    }
}

/// The right-hand number columns shared by every score row: value, "/ max" (or a unit), and a control slot,
/// all fixed width so numbers line up down the whole report.
struct ScoreColumns<Value: View, Control: View>: View {
    var max: Int? = nil
    var unit: String? = nil
    @ViewBuilder let value: () -> Value
    @ViewBuilder let control: () -> Control

    var body: some View {
        HStack(spacing: 6) {
            value().monospacedDigit().frame(width: 44, alignment: .trailing)
            Text(max.map { "/ \($0)" } ?? unit ?? "").foregroundStyle(.secondary).monospacedDigit()
                .frame(width: 44, alignment: .leading)
            // A clear placeholder keeps the slot's width in rows without a control (an EmptyView would collapse it).
            ZStack { Color.clear.frame(width: 20, height: 1); control() }.frame(width: 20)
        }
    }
}

extension ScoreColumns where Control == EmptyView {
    init(max: Int? = nil, unit: String? = nil, @ViewBuilder value: @escaping () -> Value) {
        self.init(max: max, unit: unit, value: value, control: { EmptyView() })
    }
}

// MARK: - Questions

struct QuestionSections: View, Equatable {
    @Environment(AppModel.self) private var model
    let questions: [QuestionDraft]
    let level: String?

    static func == (a: Self, b: Self) -> Bool { a.questions == b.questions && a.level == b.level }

    /// Recommended number of questions for the examination's level.
    private var range: ClosedRange<Int> {
        switch level { case "bsc": 3...5; case "phd": 8...10; default: 4...6 }
    }

    var body: some View {
        @Bindable var model = model
        let range = range
        let questions = model.draftBinding(\.questions)
        Section {
            DisclosureGroup(isExpanded: $model.vivaExpanded) {
                VStack(alignment: .leading, spacing: 14) {
                    ForEach(Array(self.questions.enumerated()), id: \.element.id) { i, q in
                        let qb = Binding(get: { questions.wrappedValue.first { $0.id == q.id } ?? q },
                                         set: { nv in if let j = questions.wrappedValue.firstIndex(where: { $0.id == q.id }) { questions.wrappedValue[j] = nv } })
                        if i > 0 { Divider() }
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Question \(i + 1)").font(.subheadline.weight(.semibold))
                                Spacer()
                                Button(role: .destructive) { questions.wrappedValue.removeAll { $0.id == q.id } } label: {
                                    Image(systemName: "trash")
                                }
                                .buttonStyle(.borderless)
                                .help("Remove this question")
                            }
                            let k = q.id.uuidString
                            LabeledField("Question", key: k + "q", text: qb.question, prompt: "As you would ask it in the viva")
                            LabeledField("Refers to", key: k + "r", text: qb.refs, prompt: "Section it grows from, e.g. §4.2")
                            LabeledField("Why ask it", key: k + "y", text: qb.why, prompt: "The gap or doubt this resolves")
                            LabeledField("Good answer", key: k + "g", text: qb.expected, prompt: "Key points an acceptable answer covers")
                            LabeledField("Weak answer", key: k + "w", text: qb.weak, prompt: "What would indicate a problem")
                        }
                    }
                    Button { questions.wrappedValue.append(QuestionDraft()) } label: { Label("Add Viva Question", systemImage: "plus.circle") }
                        .buttonStyle(.borderless)
                        .disabled(self.questions.count >= range.upperBound)
                }
                .padding(.top, 8)
            } label: {
                HStack {
                    Text("Viva Questions").font(.headline)
                    Spacer()
                    Text("\(self.questions.count) (\(range.lowerBound)–\(range.upperBound))").font(.caption).monospacedDigit()
                        .foregroundStyle(range.contains(self.questions.count) ? Color.secondary : Color.orange)
                }
            }
        }
    }
}

struct LabeledField: View {
    let label: String
    let key: String
    @Binding var text: String
    let prompt: String

    init(_ label: String, key: String, text: Binding<String>, prompt: String) {
        self.label = label; self.key = key; self._text = text; self.prompt = prompt
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.caption).foregroundStyle(.secondary)
            BufferedField(label, key: key, text: $text, prompt: prompt, axis: .vertical).labelsHidden()
            RefChips(text: text).equatable()
        }
    }
}

/// A text field that types into its own edit buffer (see AppModel.buffer), so a keystroke redraws only this field.
struct BufferedField: View {
    @Environment(AppModel.self) private var model
    let label: String
    let key: String
    @Binding var text: String
    var prompt: String? = nil
    var axis: Axis = .horizontal

    init(_ label: String, key: String, text: Binding<String>, prompt: String? = nil, axis: Axis = .horizontal) {
        self.label = label; self.key = key; self._text = text; self.prompt = prompt; self.axis = axis
    }

    var body: some View {
        let buffer = model.buffer(key, $text)
        TextField(label, text: Binding(get: { buffer.text }, set: { buffer.text = $0; model.edited(buffer) }),
                  prompt: prompt.map { Text($0) }, axis: axis)
    }
}

// MARK: - Summary and criteria

struct SummarySection: View, Equatable {
    @Environment(AppModel.self) private var model
    let summary: String
    let limit: Int

    static func == (a: Self, b: Self) -> Bool { a.summary == b.summary && a.limit == b.limit }

    var body: some View {
        @Bindable var model = model
        let text = model.draftBinding(\.summary)
        Section {
            DisclosureGroup(isExpanded: $model.summaryExpanded) {
                let summary = model.buffer("summary", text)
                TextEditor(text: Binding(get: { summary.text }, set: { summary.text = $0; model.edited(summary) }))
                    .font(.body)
                    .frame(minHeight: 170)
                    .scrollContentBackground(.hidden)
                    .padding(.top, 6)
            } label: {
                HStack {
                    Text("Summary").font(.headline)
                    Spacer()
                    let n = wordCount(model.buffer("summary", text).text)
                    Text("\(n) / \(limit) words").font(.caption).monospacedDigit()
                        .foregroundStyle(n > limit ? Color.red : Color.secondary)
                }
            }
        }
    }
}

/// Strengths and weaknesses for criteria (a) to (e), under one heading that folds away.
struct CriteriaSection: View, Equatable {
    @Environment(AppModel.self) private var model
    let criteria: [CriterionText]
    let quotes: [String: String]

    static func == (a: Self, b: Self) -> Bool { a.criteria == b.criteria && a.quotes == b.quotes }

    var body: some View {
        @Bindable var model = model
        Section {
            DisclosureGroup(isExpanded: $model.criteriaExpanded) {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(Array(criteria.enumerated()), id: \.element.id) { i, c in
                        if i > 0 { Divider().padding(.vertical, 4) }
                        Text("(\(c.key)) \(c.name)").font(.subheadline.weight(.semibold))
                        SubHeading("Strengths")
                        BulletList(items: model.criterionItems(i, strengths: true),
                                   prompt: "What the dissertation does well, with § and page", addLabel: "Add Strength", quotes: quotes)
                        SubHeading("Weaknesses")
                        BulletList(items: model.criterionItems(i, strengths: false),
                                   prompt: "What could have been done better, with § and page", addLabel: "Add Weakness", quotes: quotes)
                    }
                }
                .padding(.top, 8)
            } label: {
                HStack {
                    Text("Strengths and Weaknesses").font(.headline)
                    Spacer()
                    Text("Criteria (a)–(e)").font(.caption).foregroundStyle(.secondary)
                }
            }
        }
    }
}

// MARK: - Corrections

struct CorrectionsSection: View, Equatable {
    @Environment(AppModel.self) private var model
    let substantial: [TextItem]
    let corrections: [TextItem]

    static func == (a: Self, b: Self) -> Bool { a.substantial == b.substantial && a.corrections == b.corrections }

    var body: some View {
        @Bindable var model = model
        let substantial = self.substantial.count, minor = corrections.count
        Section {
            DisclosureGroup(isExpanded: $model.correctionsExpanded) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        SubHeading("Substantial")
                        Spacer()
                        Text(substantial == 0 ? "None required" : "\(substantial) (up to 5)").font(.caption)
                            .foregroundStyle(substantial <= 5 ? Color.secondary : Color.orange)
                    }
                    Text("Rework that needs real effort but no new research. Leave empty if none is required.")
                        .font(.caption).foregroundStyle(.secondary)
                    BulletList(items: model.draftBinding(\.substantial), prompt: "§x.y, p. N: what needs reworking → what a satisfactory revision includes",
                               addLabel: "Add Substantial Correction", numbered: true)
                    Divider()
                    HStack {
                        SubHeading("Minor")
                        Spacer()
                        Text("\(minor) (5–10)").font(.caption)
                            .foregroundStyle((5...10).contains(minor) ? Color.secondary : Color.orange)
                    }
                    BulletList(items: model.draftBinding(\.corrections), prompt: "p. N, §x.y: issue → fix", addLabel: "Add Minor Correction", numbered: true)
                }
                .padding(.top, 8)
            } label: {
                HStack {
                    Text("Corrections").font(.headline)
                    Spacer()
                    Text("\(substantial) substantial · \(minor) minor").font(.caption).monospacedDigit().foregroundStyle(.secondary)
                }
            }
        }
    }
}

// MARK: - Export

/// The last step: the signed Word report, with the viva and final marks, once the review and the viva are done.
struct ExportSection: View {
    @Environment(AppModel.self) private var model
    let blocker: String?

    var body: some View {
        Section {
            VStack(spacing: 8) {
                Button { Task { await model.exportWord() } } label: {
                    Label("Export Word Report…", systemImage: "doc.richtext").frame(minWidth: 220)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(blocker != nil || model.isSaving)
                Text(blocker ?? "Saves your edits, dates the report if needed, and produces the signed Word report with the viva and final marks, shown in Finder.")
                    .font(.caption).foregroundStyle(blocker == nil ? Color.secondary : Color.orange)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
        }
    }
}

// MARK: - Declaration

struct DeclarationSection: View {
    @Environment(AppModel.self) private var model
    @Binding var draft: ReportDraft

    static let df: DateFormatter = { let f = DateFormatter(); f.dateFormat = "dd/MM/yyyy"; return f }()

    var body: some View {
        Section("Declaration") {
            // On by default: an undated report is dated on the day it is exported.
            Toggle("Date the report", isOn: Binding(get: { !model.dateOptOut },
                                                   set: { on in model.dateOptOut = !on; if !on { draft.date = "" } else { model.dirty = true } }))
            if !model.dateOptOut {
                DatePicker("Date", selection: Binding(get: { Self.df.date(from: draft.date) ?? .now },
                                                      set: { draft.date = Self.df.string(from: $0) }),
                           displayedComponents: .date)
                if draft.date.isEmpty {
                    Text("Dated on the day you export, unless you pick a date.").font(.caption).foregroundStyle(.secondary)
                }
            }
        }
    }
}

// MARK: - Building blocks

struct BannerSection: View {
    @Environment(AppModel.self) private var model
    let banner: Banner

    var body: some View {
        Section {
            HStack(alignment: .top) {
                let (icon, color): (String, Color) = switch banner.kind {
                case .success: ("checkmark.circle.fill", .green)
                case .warning: ("exclamationmark.triangle.fill", .orange)
                case .failure: ("xmark.octagon.fill", .red)
                }
                Image(systemName: icon).foregroundStyle(color)
                Text(banner.text).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading)
                Button { model.banner = nil } label: { Image(systemName: "xmark") }
                    .buttonStyle(.borderless).foregroundStyle(.secondary).help("Dismiss")
            }
        }
    }
}

struct SubHeading: View {
    let text: String
    init(_ t: String) { text = t }
    var body: some View {
        Text(text.uppercased()).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
    }
}

struct BulletList: View {
    @Binding var items: [TextItem]
    let prompt: String
    let addLabel: String
    var numbered = false
    /// For strengths and weaknesses: the exact quotes behind each point, so its page references highlight them.
    var quotes: [String: String] = [:]

    var body: some View {
        ForEach(Array(items.enumerated()), id: \.element.id) { i, item in
            let b = Binding(get: { items.first { $0.id == item.id }?.text ?? "" },
                            set: { nv in if let j = items.firstIndex(where: { $0.id == item.id }) { items[j].text = nv } })
            let quote = quotes.isEmpty ? nil : quotes[evidenceKey(item.text)]
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(numbered ? "\(i + 1)." : "•").foregroundStyle(.secondary).monospacedDigit()
                    .frame(width: 22, alignment: .trailing)
                VStack(alignment: .leading, spacing: 3) {
                    BufferedField("Item", key: item.id.uuidString, text: b, prompt: prompt, axis: .vertical).labelsHidden()
                    RefChips(text: item.text, highlights: quote.map { [$0] + evidenceAnchors(in: item.text) } ?? []).equatable()
                }
                Button(role: .destructive) { items.removeAll { $0.id == item.id } } label: {
                    Image(systemName: "minus.circle")
                }
                .buttonStyle(.borderless)
                .foregroundStyle(.secondary)
                .help("Remove")
            }
        }
        Button { items.append(TextItem(text: "")) } label: { Label(addLabel, systemImage: "plus.circle") }
            .buttonStyle(.borderless)
    }
}

/// Clickable printed-page references that open the dissertation at that page.
struct RefChips: View, Equatable {
    @Environment(AppModel.self) private var model
    let text: String
    let highlights: [String]

    init(text: String, highlights: [String] = []) {
        self.text = text
        self.highlights = highlights
    }

    static func == (lhs: Self, rhs: Self) -> Bool { lhs.text == rhs.text && lhs.highlights == rhs.highlights }

    var body: some View {
        let refs = pageRefs(in: text)
        if !refs.isEmpty {
            HStack(spacing: 6) {
                ForEach(refs, id: \.self) { r in
                    Button { model.openPDF(at: r, highlighting: highlights.isEmpty ? evidenceAnchors(in: text) : highlights, context: text) } label: {
                        Label(r.title, systemImage: "doc.text.magnifyingglass")
                            .font(.caption)
                            .padding(.horizontal, 6).padding(.vertical, 1)
                            .background(.quaternary.opacity(0.6), in: .capsule)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(Color.accentColor)
                    .help("Open \(r.title) of the dissertation and highlight the passage this refers to")
                }
            }
        }
    }
}
