import AppKit
import SwiftUI

struct ReportEditor: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let draft = Binding<ReportDraft>(
            get: { model.draft ?? ReportDraft() },
            set: { model.draft = $0; model.dirty = true })
        let detail = model.detail
        Form {
            Section { ScoreHeader(draft: draft.wrappedValue) }
            if let b = model.banner { BannerSection(banner: b) }
            MarksSections(draft: draft)

            Section("Details") {
                TextField("Student name", text: draft.student)
                TextField("Title", text: draft.title, axis: .vertical)
                TextField("Degree", text: draft.degree)
                TextField("Institution", text: draft.institution)
                TextField("Examiner", text: draft.examiner)
            }

            Section {
                TextEditor(text: draft.summary)
                    .font(.body)
                    .frame(minHeight: 170)
                    .scrollContentBackground(.hidden)
                RefChips(text: draft.wrappedValue.summary)
            } header: {
                HStack {
                    Text("Summary")
                    Spacer()
                    let n = wordCount(draft.wrappedValue.summary)
                    Text("\(n) / 250 words").monospacedDigit()
                        .foregroundStyle(n > 250 ? .red : .secondary)
                }
            }

            ForEach(draft.criteria) { $c in
                Section {
                    SubHeading("Strengths")
                    BulletList(items: $c.strengths, prompt: "What the dissertation does well, with § and page", addLabel: "Add Strength")
                    SubHeading("Weaknesses")
                    BulletList(items: $c.weaknesses, prompt: "What could have been done better, with § and page", addLabel: "Add Weakness")
                } header: {
                    HStack {
                        Text("(\(c.spec.key)) \(c.spec.name)")
                        Spacer()
                        Text("\(c.mark) / \(c.spec.max)").monospacedDigit()
                    }
                }
            }

            QuestionSections(questions: draft.questions)

            Section {
                BulletList(items: draft.corrections, prompt: "p. N, §x.y: issue → fix", addLabel: "Add Correction", numbered: true)
            } header: {
                HStack {
                    Text("Minor Corrections")
                    Spacer()
                    let n = draft.wrappedValue.corrections.count
                    Text("\(n) (5–10)").foregroundStyle((5...10).contains(n) ? Color.secondary : Color.orange)
                }
            }

            DeclarationSection(draft: draft)

            if let msg = detail?.status.message, !msg.isEmpty {
                Section {
                    DisclosureGroup("Claude's note on this report") {
                        Text(msg).textSelection(.enabled).font(.callout).frame(maxWidth: .infinity, alignment: .leading).padding(.top, 4)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .sensoryFeedback(.success, trigger: model.saveCount)
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
                            .animation(.spring(duration: 0.4), value: c.mark)
                        if let p = detail?.proposedMark(c.spec.key) {
                            Text("Claude \(p)")
                                .font(.caption)
                                .foregroundStyle(p == c.mark ? Color.secondary : Color.orange)
                                .help(p == c.mark ? "Claude's proposed mark" : "You changed this from Claude's \(p)")
                        }
                        Text("\(c.mark)").font(.body.weight(.semibold)).monospacedDigit().frame(minWidth: 22, alignment: .trailing)
                        Text("/ \(c.spec.max)").foregroundStyle(.secondary).monospacedDigit().frame(minWidth: 30, alignment: .leading)
                        Stepper("Mark", value: Binding(get: { c.mark }, set: { model.setMark(i, $0) }), in: 0...c.spec.max)
                            .labelsHidden()
                    }
                } label: {
                    Text("(\(c.spec.key)) \(c.spec.name)")
                }
            }
        }

        Section {
            Slider(value: Binding(get: { model.slider }, set: { model.applySlider($0) }), in: -15...15, step: 1) {
                Text("Overall")
            } minimumValueLabel: {
                Text("Harsher").font(.caption)
            } maximumValueLabel: {
                Text("More generous").font(.caption)
            }
            if let pt = model.proposedTotal {
                LabeledContent("Claude's proposal", value: "\(pt) / 90")
                LabeledContent("Your adjustment") {
                    let d = draft.total - pt
                    Text(d == 0 ? "None" : Fmt.signed(Double(d)) + " marks")
                        .foregroundStyle(d > 0 ? Color.green : d < 0 ? Color.red : Color.secondary)
                        .monospacedDigit()
                }
            }
            TextField("Why you adjusted", text: Binding(get: { model.note }, set: { model.note = $0; model.dirty = true }),
                      prompt: Text("Optional, e.g. “credit honest negative results in (d)”"), axis: .vertical)
            if let applied = model.detail?.applied {
                let nonZero = CRITERIA.compactMap { s -> String? in
                    guard let v = applied[s.key] ?? nil, v != 0 else { return nil }
                    return "(\(s.key)) \(Fmt.signed(v))"
                }
                if !nonZero.isEmpty {
                    Label("Claude already applied your learned offsets: \(nonZero.joined(separator: ", "))", systemImage: "dial.medium")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
        } header: {
            HStack {
                Text("Overall Calibration")
                Spacer()
                Text(model.slider == 0 ? "0" : Fmt.signed(model.slider)).monospacedDigit()
            }
        } footer: {
            Text("Moves the whole mark down or up, spread over the criteria by weight. Fine-tune any criterion above. Each save teaches the skill your calibration for the next \(Level(rawValue: model.detail?.status.level ?? "msc")?.label ?? "") examination.")
                .font(.caption).foregroundStyle(.secondary)
        }

        Section("Result") {
            LabeledContent("Dissertation") {
                Text("\(draft.total) / 90").font(.title3.weight(.semibold)).monospacedDigit()
            }
            LabeledContent("Viva") {
                HStack(spacing: 6) {
                    TextField("Viva", text: $draft.vivaText, prompt: Text("after the oral"))
                        .labelsHidden()
                        .multilineTextAlignment(.trailing)
                        .frame(width: 110)
                        .foregroundStyle(draft.vivaInvalid ? .red : .primary)
                    Text("/ 10").foregroundStyle(.secondary)
                }
            }
            LabeledContent("Final mark") {
                Text(draft.viva.map { "\(Fmt.mark(Double(draft.total) + $0)) / 100" } ?? "– / 100")
                    .font(.title3.weight(.bold)).monospacedDigit()
                    .foregroundStyle(draft.viva == nil ? Color.secondary : Color.accentColor)
            }
        }
    }
}

// MARK: - Questions

struct QuestionSections: View {
    @Binding var questions: [QuestionDraft]

    var body: some View {
        ForEach(Array(questions.enumerated()), id: \.element.id) { i, q in
            let qb = Binding(get: { questions.first { $0.id == q.id } ?? q },
                             set: { nv in if let j = questions.firstIndex(where: { $0.id == q.id }) { questions[j] = nv } })
            Section {
                LabeledField("Question", text: qb.question, prompt: "As you would ask it in the viva")
                LabeledField("Refers to", text: qb.refs, prompt: "§x.y, p. N")
                LabeledField("Why ask it", text: qb.why, prompt: "The gap or doubt this resolves")
                LabeledField("Good answer", text: qb.expected, prompt: "Key points an acceptable answer covers")
                LabeledField("Weak answer", text: qb.weak, prompt: "What would indicate a problem")
            } header: {
                HStack {
                    Text(i == 0 ? "Viva Questions · Question 1" : "Question \(i + 1)")
                    Spacer()
                    Button(role: .destructive) { questions.removeAll { $0.id == q.id } } label: {
                        Image(systemName: "trash")
                    }
                    .buttonStyle(.borderless)
                    .help("Remove this question")
                }
            }
        }
        Section {
            Button { questions.append(QuestionDraft()) } label: { Label("Add Viva Question", systemImage: "plus.circle") }
                .buttonStyle(.borderless)
                .disabled(questions.count >= 5)
        } footer: {
            Text("\(questions.count) question\(questions.count == 1 ? "" : "s"), 3–5 recommended.").font(.caption).foregroundStyle(.secondary)
        }
    }
}

struct LabeledField: View {
    let label: String
    @Binding var text: String
    let prompt: String

    init(_ label: String, text: Binding<String>, prompt: String) {
        self.label = label; self._text = text; self.prompt = prompt
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.caption).foregroundStyle(.secondary)
            TextField(label, text: $text, prompt: Text(prompt), axis: .vertical).labelsHidden()
            RefChips(text: text)
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
            LabeledContent("Signature") {
                if let img = NSImage(contentsOf: model.backend.signatureURL) {
                    Image(nsImage: img).resizable().scaledToFit().frame(height: 52)
                        .padding(6).background(.white, in: .rect(cornerRadius: 6))
                } else {
                    Text("No signature found").foregroundStyle(.secondary)
                }
            }
            Toggle("Date the report", isOn: Binding(get: { !draft.date.isEmpty },
                                                   set: { draft.date = $0 ? Self.df.string(from: .now) : "" }))
            if !draft.date.isEmpty {
                DatePicker("Date", selection: Binding(get: { Self.df.date(from: draft.date) ?? .now },
                                                      set: { draft.date = Self.df.string(from: $0) }),
                           displayedComponents: .date)
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

    var body: some View {
        ForEach(Array(items.enumerated()), id: \.element.id) { i, item in
            let b = Binding(get: { items.first { $0.id == item.id }?.text ?? "" },
                            set: { nv in if let j = items.firstIndex(where: { $0.id == item.id }) { items[j].text = nv } })
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(numbered ? "\(i + 1)." : "•").foregroundStyle(.secondary).monospacedDigit()
                VStack(alignment: .leading, spacing: 3) {
                    TextField("Item", text: b, prompt: Text(prompt), axis: .vertical).labelsHidden()
                    RefChips(text: item.text)
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
struct RefChips: View {
    @Environment(AppModel.self) private var model
    let text: String

    var body: some View {
        let refs = pageRefs(in: text)
        if !refs.isEmpty {
            HStack(spacing: 6) {
                ForEach(refs, id: \.self) { r in
                    Button { model.openPDF(at: r) } label: {
                        Label("p. \(r)", systemImage: "doc.text.magnifyingglass")
                            .font(.caption)
                            .padding(.horizontal, 6).padding(.vertical, 1)
                            .background(.quaternary.opacity(0.6), in: .capsule)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(Color.accentColor)
                    .help("Show page \(r) of the dissertation")
                }
            }
        }
    }
}
