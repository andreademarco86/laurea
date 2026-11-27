import AppKit
import SwiftUI

// MARK: - Tones and policies

/// Colour of a recommendation option's tone: accept, borderline, revise or reject.
func toneColor(_ tone: String?) -> Color {
    switch tone {
    case "accept": .green
    case "borderline": .orange
    case "revise": .blue
    case "reject": .red
    default: .secondary
    }
}

struct ToneCapsule: View {
    let text: String
    let tone: String?
    @Environment(\.backgroundProminence) private var prominence

    var body: some View {
        let selected = prominence == .increased
        Text(text)
            .font(.caption2.weight(.bold))
            .lineLimit(1)
            .padding(.horizontal, 7).padding(.vertical, 2)
            .foregroundStyle(selected ? Color.white : toneColor(tone))
            .background(selected ? Color.black.opacity(0.18) : toneColor(tone).opacity(0.15), in: .capsule)
    }
}

/// The one proviso, shown where a review starts: reviews are pre-submission reviews; refereeing with them is the
/// reviewer's own responsibility under the venue's rules.
struct RefereeingNote: View {
    var body: some View {
        Label {
            Text("Reviews are meant for checking a paper before it is submitted. If you use one to referee a submission, that is your responsibility: many venues don't allow sharing submissions under review, or ask you to declare it.")
        } icon: {
            Image(systemName: "info.circle")
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
    }
}

// MARK: - Start

struct ReviewStartView: View {
    @Environment(AppModel.self) private var model
    let detail: ExamDetail

    var body: some View {
        @Bindable var model = model
        ScrollView {
            VStack(spacing: 18) {
                Image(systemName: "doc.text.magnifyingglass")
                    .font(.system(size: 54, weight: .light))
                    .foregroundStyle(.secondary)
                Text(detail.status.original_name ?? detail.pdf).font(.title2.weight(.semibold))
                if ["error", "interrupted", "cancelled"].contains(detail.state), let msg = detail.status.message, !msg.isEmpty {
                    GroupBox {
                        ScrollView {
                            Text(msg).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .frame(maxHeight: 180)
                    } label: {
                        Label("The last run didn't finish", systemImage: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                    }
                    .frame(maxWidth: 560)
                } else {
                    Text("Laurea reviews the paper as a careful referee at your target venue would, on the venue's own form and scale, so you can see what to fix before submitting.")
                        .multilineTextAlignment(.center).foregroundStyle(.secondary).frame(maxWidth: 480)
                }
                VenuePicker(selection: $model.newVenueID, venues: model.venues)
                    .frame(maxWidth: 560)
                if let v = model.newVenue {
                    VenueCard(venue: v).frame(maxWidth: 560)
                }
                Button { Task { await model.examine() } } label: {
                    Text(detail.state == "new" ? "Review Paper" : "Run Again").frame(minWidth: 180)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .keyboardShortcut(.defaultAction)
                .disabled(model.newVenue == nil)
                RefereeingNote().frame(maxWidth: 480)
            }
            .padding(40)
            .frame(maxWidth: .infinity)
        }
    }
}

/// Venues grouped into conferences and journals, searchable by name.
struct VenuePicker: View {
    @Binding var selection: String
    let venues: [Venue]

    var body: some View {
        Picker("Target venue", selection: $selection) {
            Section("Conferences") {
                ForEach(venues.filter { $0.kind == "conference" }) { Text($0.name).tag($0.id) }
            }
            Section("Journals") {
                ForEach(venues.filter { $0.kind == "journal" }) { Text($0.name).tag($0.id) }
            }
        }
        .pickerStyle(.menu)
        .frame(maxWidth: 360)
    }
}

/// What reviewing for this venue involves: its form, scale and policy.
struct VenueCard: View {
    let venue: Venue

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(venue.full_name).font(.headline)
                    Text(details).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
            }
            VStack(alignment: .leading, spacing: 6) {
                Text(venue.recommendation.name.uppercased()).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                ScaleStrip(options: venue.recommendation.options, selected: nil, proposed: nil, onSelect: nil)
            }
            if !venue.scoreList.isEmpty || venue.confidence != nil {
                Text("Also scored: " + (venue.scoreList.map(\.name) + (venue.confidence.map { [$0.name] } ?? [])).joined(separator: ", "))
                    .font(.caption).foregroundStyle(.secondary)
            }
            if let notes = venue.notes, !notes.isEmpty {
                Text(notes).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .background(.quaternary.opacity(0.35), in: .rect(cornerRadius: 12))
    }

    private var details: String {
        var parts = [venue.isJournal ? "Journal" : "Conference"]
        if let a = venue.anonymity { parts.append(a == "double" ? "double-anonymous" : "single-anonymous") }
        switch venue.form {
        case "published": parts.append("reviewer form \(venue.form_year.map(String.init) ?? "")")
        case "partial": parts.append("form not public; scale follows recent practice")
        default: parts.append("general scale")
        }
        return parts.joined(separator: " · ")
    }
}

/// A venue's recommendation scale, worst on the left and best on the right, coloured by tone. With `onSelect`,
/// clicking an option chooses it; the proposed option has a dot beneath it.
struct ScaleStrip: View {
    let options: [VenueOption]
    let selected: String?
    let proposed: String?
    let onSelect: ((String) -> Void)?

    var body: some View {
        HStack(spacing: 3) {
            ForEach(options.reversed(), id: \.value) { o in
                let isSelected = o.value == selected
                let tint = toneColor(o.tone)
                let cell = VStack(spacing: 3) {
                    Text(o.short)
                        .font(.caption.weight(isSelected ? .bold : .regular))
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .frame(maxWidth: .infinity, minHeight: 26)
                        .foregroundStyle(isSelected ? Color.white : tint)
                        .background(isSelected ? AnyShapeStyle(tint) : AnyShapeStyle(tint.opacity(0.14)), in: .rect(cornerRadius: 6))
                    Circle().fill(Color.secondary).frame(width: 4, height: 4).opacity(o.value == proposed ? 1 : 0)
                }
                .help(o.text + (o.meaning.map { $0.isEmpty ? "" : "\n\($0)" } ?? "") + (o.value == proposed ? "\nProposed" : ""))
                .accessibilityLabel(o.text + (isSelected ? ", selected" : "") + (o.value == proposed ? ", proposed" : ""))
                if let onSelect {
                    Button { onSelect(o.value) } label: { cell }.buttonStyle(.plain)
                } else {
                    cell
                }
            }
        }
    }
}

// MARK: - Editor

struct ReviewEditor: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let r = model.reviewDraft ?? ReviewDraft()
        let detail = model.detail
        if let venue = detail?.venue_form {
            Form {
                Section { ReviewHeader(review: r, venue: venue) }
                if let b = model.banner { BannerSection(banner: b) }
                RatingsSection(review: r, venue: venue, proposed: detail?.proposed_review)
                ReviewDetailsSection(paper: r.paper, venue: venue).equatable()
                ReviewSummarySection(summary: r.summary, limit: detail?.summary_words ?? 350).equatable()
                ReviewPointsSection(strengths: r.strengths, weaknesses: r.weaknesses).equatable()
                ReviewQuestionsSection(questions: r.questions).equatable()
                ReviewChangesSection(major: r.major, moderate: r.moderate, minor: r.minor, journal: venue.isJournal).equatable()
                ReviewNotesSection(limitations: r.limitations, ethics: r.ethics, confidential: r.confidential).equatable()
                SubmitSection(venue: venue, form: detail?.form, dirty: model.dirty)
                if let panel = detail?.panel_review {
                    ReviewInternalNotes(panel: panel, venue: venue).equatable()
                }
            }
            .formStyle(.grouped)
            .sensoryFeedback(.success, trigger: model.saveCount)
        } else {
            ContentUnavailableView("This review's venue is unavailable", systemImage: "exclamationmark.triangle")
        }
    }
}

struct ReviewHeader: View {
    @Environment(AppModel.self) private var model
    let review: ReviewDraft
    let venue: Venue

    var body: some View {
        let rec = venue.recommendation.option(review.recommendation)
        HStack(alignment: .center, spacing: 22) {
            ZStack {
                RoundedRectangle(cornerRadius: 18).fill(toneColor(rec?.tone).gradient.opacity(0.18))
                VStack(spacing: 2) {
                    Text(rec?.short ?? "–")
                        .font(.system(size: (rec.map { Double($0.value) != nil } ?? true) ? 34 : 17, weight: .bold, design: .rounded))
                        .foregroundStyle(toneColor(rec?.tone))
                        .lineLimit(2).minimumScaleFactor(0.6).multilineTextAlignment(.center)
                        .contentTransition(.numericText())
                    Text(venue.recommendation.name).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                }
                .padding(8)
            }
            .frame(width: 104, height: 92)
            .animation(.snappy(duration: 0.18), value: review.recommendation)
            VStack(alignment: .leading, spacing: 8) {
                Text(review.paper.isEmpty ? "Untitled paper" : review.paper)
                    .font(.title3.weight(.semibold)).lineLimit(3)
                // The big tile shows the number on numeric scales, so name the option here; worded scales already show it.
                if rec?.isNumeric ?? true {
                    Text(rec.map { $0.label } ?? "No recommendation yet").foregroundStyle(.secondary)
                }
                HStack(spacing: 8) {
                    ToneCapsule(text: venue.name, tone: nil)
                    if let p = model.detail?.proposed_review?.recommendation, let o = venue.recommendation.option(p) {
                        Pill(text: "Proposed \(o.short)", icon: "doc.text", tint: .secondary).help("Proposed: \(o.text)")
                    }
                    if model.dirty {
                        Pill(text: "Edited", icon: "pencil", tint: .orange)
                    } else {
                        Pill(text: "Saved", icon: "checkmark.circle.fill", tint: .green)
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 8)
    }
}

/// The recommendation, the venue's scores and confidence, each with what was proposed.
struct RatingsSection: View {
    @Environment(AppModel.self) private var model
    let review: ReviewDraft
    let venue: Venue
    let proposed: ProposedReview?

    var body: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                ScaleStrip(options: venue.recommendation.options, selected: review.recommendation,
                           proposed: proposed?.recommendation, onSelect: { model.setRecommendation($0) })
                // What the chosen option means at this venue, when the venue says.
                if let m = venue.recommendation.option(review.recommendation)?.meaning, !m.isEmpty {
                    Text(m).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.vertical, 4)
            ForEach(venue.scoreList) { s in
                ratingRow(s.name, options: s.options, value: review.scores[s.key] ?? "", proposed: proposed?.scores?[s.key]) { v in
                    model.reviewBinding(\.scores).wrappedValue[s.key] = v
                }
            }
            if let c = venue.confidence {
                ratingRow(c.name, options: c.options, value: review.confidence, proposed: proposed?.confidence) { v in
                    model.reviewBinding(\.confidence).wrappedValue = v
                }
            }
            BufferedField("Why you changed it", key: "note", text: Binding(get: { model.note }, set: { model.note = $0 }),
                          prompt: "Optional, e.g. “the missing baseline matters less at this venue”", axis: .vertical)
        } header: {
            Text(venue.recommendation.name)
        } footer: {
            Text("Click an option to change the recommendation; the dot marks the proposal. The summary's closing sentence follows your choice. Laurea learns from recommendations you change consistently across reviews.")
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    private func ratingRow(_ name: String, options: [VenueOption], value: String, proposed: String?,
                           set: @escaping (String) -> Void) -> some View {
        LabeledContent {
            HStack(spacing: 10) {
                Group {
                    if let p = proposed, let o = options.first(where: { $0.value == p }) {
                        Text("Proposed \(o.short)")
                            .foregroundStyle(p == value ? Color.secondary : Color.orange)
                            .help(p == value ? "Proposed: \(o.text)" : "You changed this from the proposed \(o.text)")
                    } else {
                        Text("")
                    }
                }
                .font(.caption.monospacedDigit())
                .frame(width: 110, alignment: .trailing)
                Picker(name, selection: Binding(get: { value }, set: set)) {
                    if value.isEmpty { Text("Choose…").tag("") }
                    ForEach(options, id: \.value) { Text($0.text).tag($0.value) }
                }
                .labelsHidden()
                .frame(width: 260)
            }
        } label: {
            Text(name)
        }
    }
}

struct ReviewDetailsSection: View, Equatable {
    @Environment(AppModel.self) private var model
    let paper: String
    let venue: Venue

    static func == (a: Self, b: Self) -> Bool { a.paper == b.paper && a.venue == b.venue }

    var body: some View {
        Section("Paper") {
            BufferedField("Title", key: "paper", text: model.reviewBinding(\.paper), axis: .vertical)
            LabeledContent("Target venue", value: venue.full_name)
        }
    }
}

struct ReviewSummarySection: View, Equatable {
    @Environment(AppModel.self) private var model
    let summary: String
    let limit: Int

    static func == (a: Self, b: Self) -> Bool { a.summary == b.summary && a.limit == b.limit }

    var body: some View {
        @Bindable var model = model
        let text = model.reviewBinding(\.summary)
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

struct ReviewPointsSection: View, Equatable {
    @Environment(AppModel.self) private var model
    let strengths: [TextItem]
    let weaknesses: [TextItem]

    static func == (a: Self, b: Self) -> Bool { a.strengths == b.strengths && a.weaknesses == b.weaknesses }

    var body: some View {
        @Bindable var model = model
        Section {
            DisclosureGroup(isExpanded: $model.criteriaExpanded) {
                VStack(alignment: .leading, spacing: 10) {
                    SubHeading("Strengths")
                    BulletList(items: model.reviewBinding(\.strengths), prompt: "What the paper does well, and where (§, page, table, figure or line)",
                               addLabel: "Add Strength", numbered: true)
                    Divider().padding(.vertical, 4)
                    SubHeading("Weaknesses")
                    Text("Numbered W1, W2, … so the questions and changes can refer to them. Most important first.")
                        .font(.caption).foregroundStyle(.secondary)
                    BulletList(items: model.reviewBinding(\.weaknesses), prompt: "What is missing or wrong, why it matters, and where",
                               addLabel: "Add Weakness", numbered: true, prefix: "W")
                }
                .padding(.top, 8)
            } label: {
                HStack {
                    Text("Strengths and Weaknesses").font(.headline)
                    Spacer()
                    Text("\(strengths.count) strengths · \(weaknesses.count) weaknesses").font(.caption).monospacedDigit()
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

struct ReviewQuestionsSection: View, Equatable {
    @Environment(AppModel.self) private var model
    let questions: [TextItem]

    static func == (a: Self, b: Self) -> Bool { a.questions == b.questions }

    var body: some View {
        @Bindable var model = model
        Section {
            DisclosureGroup(isExpanded: $model.vivaExpanded) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Questions whose answers could change your assessment, saying how. End with the weakness they relate to, e.g. (W2).")
                        .font(.caption).foregroundStyle(.secondary)
                    BulletList(items: model.reviewBinding(\.questions), prompt: "A question for the authors (W1)",
                               addLabel: "Add Question", numbered: true)
                }
                .padding(.top, 8)
            } label: {
                HStack {
                    Text("Questions for the Authors").font(.headline)
                    Spacer()
                    Text("\(questions.count) (3–6)").font(.caption).monospacedDigit()
                        .foregroundStyle((3...6).contains(questions.count) ? Color.secondary : Color.orange)
                }
            }
        }
    }
}

struct ReviewChangesSection: View, Equatable {
    @Environment(AppModel.self) private var model
    let major: [TextItem]
    let moderate: [TextItem]
    let minor: [TextItem]
    let journal: Bool

    static func == (a: Self, b: Self) -> Bool {
        a.major == b.major && a.moderate == b.moderate && a.minor == b.minor && a.journal == b.journal
    }

    var body: some View {
        @Bindable var model = model
        Section {
            DisclosureGroup(isExpanded: $model.correctionsExpanded) {
                VStack(alignment: .leading, spacing: 10) {
                    tier("Major", count: major.count,
                         about: "Heavy revision a main claim depends on: new or rerun experiments, missing baselines or ablations, statistical tests, narrowing a claim, a new title. Only where necessary.",
                         items: model.reviewBinding(\.major), prompt: "§x.y: what is wrong → what to do (W1)", add: "Add Major Change")
                    Divider()
                    tier("Moderate", count: moderate.count,
                         about: "Rework with what the authors already have: clarify the method, reposition against related work, analyse existing results.",
                         items: model.reviewBinding(\.moderate), prompt: "§x.y: what is wrong → what to do (W2)", add: "Add Moderate Change")
                    Divider()
                    tier("Minor", count: minor.count, about: "Quick fixes: typos, notation, figures, references, unclear sentences.",
                         items: model.reviewBinding(\.minor), prompt: "p. N, §x.y: issue → fix", add: "Add Minor Change")
                }
                .padding(.top, 8)
            } label: {
                HStack {
                    Text("Required Changes").font(.headline)
                    Spacer()
                    Text("\(major.count) major · \(moderate.count) moderate · \(minor.count) minor").font(.caption).monospacedDigit()
                        .foregroundStyle(.secondary)
                }
            }
        } footer: {
            Text(journal ? "For a journal, these are what the revised manuscript needs." : "For a conference, these are what would make the paper acceptable or stronger for the final version.")
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private func tier(_ title: String, count: Int, about: String, items: Binding<[TextItem]>, prompt: String, add: String) -> some View {
        HStack {
            SubHeading(title)
            Spacer()
            Text(count == 0 ? "None required" : "\(count)").font(.caption).monospacedDigit().foregroundStyle(.secondary)
        }
        Text(about).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        BulletList(items: items, prompt: prompt, addLabel: add, numbered: true)
    }
}

struct ReviewNotesSection: View, Equatable {
    @Environment(AppModel.self) private var model
    let limitations: String
    let ethics: String
    let confidential: String

    static func == (a: Self, b: Self) -> Bool {
        (a.limitations, a.ethics, a.confidential) == (b.limitations, b.ethics, b.confidential)
    }

    var body: some View {
        Section {
            LabeledField("Limitations and broader impact", key: "limitations", text: model.reviewBinding(\.limitations),
                         prompt: "Whether the authors discuss them adequately; if not, what to add")
            LabeledField("Ethical concerns", key: "ethics", text: model.reviewBinding(\.ethics), prompt: "None")
            VStack(alignment: .leading, spacing: 4) {
                Label("Confidential comments to the area chair or editor", systemImage: "lock")
                    .font(.caption).foregroundStyle(.secondary)
                BufferedField("Confidential comments", key: "confidential", text: model.reviewBinding(\.confidential),
                              prompt: "None. Not shared with the authors.", axis: .vertical).labelsHidden()
            }
        }
    }
}

/// The last step: the review laid out as the venue's own form, field by field, ready to copy or export.
struct SubmitSection: View {
    @Environment(AppModel.self) private var model
    let venue: Venue
    let form: ReviewForm?
    let dirty: Bool

    var body: some View {
        Section {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(form?.fields ?? [], id: \.title) { f in
                    HStack(alignment: .firstTextBaseline) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(f.title).font(.callout.weight(.semibold))
                            Text(f.text.replacingOccurrences(of: "\n", with: " "))
                                .font(.caption).foregroundStyle(.secondary).lineLimit(2)
                        }
                        Spacer()
                        Button("Copy") { Task { await model.copyReviewForm(field: f.title) } }
                            .controlSize(.small)
                            .help("Copy this field for the venue's review form")
                    }
                }
                if let ratings = form?.ratings, !ratings.isEmpty {
                    Divider()
                    ForEach(ratings, id: \.name) { r in
                        LabeledContent(r.name, value: r.value.isEmpty ? "–" : r.value).font(.callout)
                    }
                }
                HStack(spacing: 10) {
                    Button { Task { await model.copyReviewForm() } } label: {
                        Label("Copy Whole Review", systemImage: "doc.on.clipboard").frame(minWidth: 180)
                    }
                    .buttonStyle(.borderedProminent)
                    Button { Task { await model.exportReview() } } label: {
                        Label("Export Word…", systemImage: "doc.richtext")
                    }
                    .help("A Word copy of the review, for journals that take the report as a file")
                }
                .controlSize(.large)
                .frame(maxWidth: .infinity)
                .padding(.top, 6)
                Text(dirty ? "Copying saves your edits first." : "The whole review is laid out as \(venue.name)'s review form, field by field.")
                    .font(.caption).foregroundStyle(.secondary).frame(maxWidth: .infinity)
            }
            .padding(.vertical, 4)
        } header: {
            Text("Copy and Export")
        }
    }
}

/// The three reviewers' and the area chair's ratings, their one-line views and the rulings on disagreements.
struct ReviewInternalNotes: View, Equatable {
    let panel: ReviewPanel
    let venue: Venue

    private let roles = ["soundness", "novelty", "clarity", "chair"]

    var body: some View {
        Section {
            DisclosureGroup("Internal notes") {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Reviewers and Area Chair").font(.subheadline.weight(.semibold))
                    Grid(horizontalSpacing: 10, verticalSpacing: 8) {
                        GridRow {
                            Text("").frame(maxWidth: .infinity, alignment: .leading)
                            ForEach(roles, id: \.self) { role in
                                Text(title(role)).fontWeight(role == "chair" ? .semibold : .regular)
                            }
                        }
                        .font(.caption).foregroundStyle(.secondary)
                        ForEach(items, id: \.key) { item in
                            GridRow {
                                HStack(spacing: 6) {
                                    Text(item.name).lineLimit(1)
                                    Image(systemName: "exclamationmark.circle").foregroundStyle(.orange)
                                        .opacity(panel.low_confidence.contains(item.key) ? 1 : 0)
                                        .help("Lower confidence: the reviewers disagreed")
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                ForEach(roles, id: \.self) { role in
                                    let value = (role == "chair" ? panel.chair : panel.reviewers[role] ?? [:])[item.key]
                                    let option = item.options.first { $0.value == value }
                                    Text(option?.short ?? "–")
                                        .font(.caption.monospacedDigit().weight(role == "chair" ? .semibold : .regular))
                                        .foregroundStyle(option == nil ? Color.secondary : item.key == "recommendation" ? toneColor(option?.tone) : Color.primary)
                                        .lineLimit(1)
                                        .help(option?.text ?? "")
                                }
                            }
                        }
                    }
                    Grid(alignment: .topLeading, horizontalSpacing: 12, verticalSpacing: 6) {
                        ForEach(roles, id: \.self) { role in
                            if let note = role == "chair" ? panel.summary : panel.notes[role], !note.isEmpty {
                                GridRow {
                                    Text(title(role)).fontWeight(.semibold).frame(width: 84, alignment: .leading)
                                    Text(PanelReview.plain(note)).foregroundStyle(.secondary).textSelection(.enabled)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                .font(.callout)
                            }
                        }
                        ForEach(items.filter { panel.decisions[$0.key] != nil }, id: \.key) { item in
                            GridRow {
                                Text(item.name).fontWeight(.semibold).frame(width: 84, alignment: .leading).lineLimit(2)
                                Text(PanelReview.plain(panel.decisions[item.key] ?? "")).foregroundStyle(.secondary)
                                    .textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .font(.callout)
                        }
                    }
                    Text("The area chair's ratings are before your learned tendency is applied. Rulings are for items where the reviewers disagreed.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 8)
            }
        }
    }

    private struct Item { let key: String; let name: String; let options: [VenueOption] }

    private var items: [Item] {
        [Item(key: "recommendation", name: venue.recommendation.name, options: venue.recommendation.options)]
            + venue.scoreList.map { Item(key: $0.key, name: $0.name, options: $0.options) }
            + (venue.confidence.map { [Item(key: "confidence", name: $0.name, options: $0.options)] } ?? [])
    }

    private func title(_ role: String) -> String { role == "chair" ? "Area chair" : role.capitalized }
}
