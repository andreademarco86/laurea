import Observation
import Foundation

// MARK: - Marking scheme (criterion weights = maximum marks; criteria + viva = 100)

struct CriterionSpec: Hashable {
    let key: String
    let name: String
    let max: Int
}

let CRITERIA: [CriterionSpec] = [
    .init(key: "a", name: "Introduction and overall document", max: 10),
    .init(key: "b", name: "Literature Review", max: 20),
    .init(key: "c", name: "Method and Solution", max: 25),
    .init(key: "d", name: "Testing, Results, Analysis and Evaluation", max: 25),
    .init(key: "e", name: "Discussion, Conclusion and Future Work", max: 10),
]

struct Scheme: Equatable {
    static let defaults: [String: Int] = ["a": 10, "b": 20, "c": 25, "d": 25, "e": 10, "viva": 10]
    var weights: [String: Int]

    init(_ w: [String: Int]?) {
        if let w, Scheme.isValid(w) { weights = w } else { weights = Scheme.defaults }
    }

    static func isValid(_ w: [String: Int]) -> Bool {
        let crit = CRITERIA.map { w[$0.key] ?? 0 }
        return crit.allSatisfy { $0 >= 1 } && (w["viva"] ?? -1) >= 0 && crit.reduce(0, +) + (w["viva"] ?? 0) == 100
    }

    func max(_ key: String) -> Int { weights[key] ?? Scheme.defaults[key] ?? 0 }
    var viva: Int { weights["viva"] ?? 10 }
    var dissertationMax: Int { 100 - viva }
    var specs: [CriterionSpec] { CRITERIA.map { .init(key: $0.key, name: $0.name, max: max($0.key)) } }
}

// MARK: - API types (mirror the engine's JSON)

struct ExamSummary: Codable, Identifiable, Hashable {
    let id: String
    let state: String
    let pdf: String
    let created: String
    let student: String
    let title: String
    let total: Double?
    let viva: Double?
    var level: String?
    var dissertation_max: Int?
    var progress: Double?
    var phase: String?
    var run_kind: String?
    /// "review" for a paper review, otherwise an examination.
    var kind: String?
    var venue: String?
    var recommendation: String?
    var tone: String?

    var isReview: Bool { kind == "review" }
    var fileName: String { (pdf as NSString).deletingPathExtension.replacingOccurrences(of: "_", with: " ") }
    var displayName: String {
        if isReview { return title.isEmpty ? fileName : title }
        return student.isEmpty ? fileName : student
    }
}

struct ExamStatus: Codable {
    var state: String?
    var pdf: String?
    var original_name: String?
    var message: String?
    var run_kind: String?
    var started: String?
    var level: String?
    var date_opt_out: Bool?
    var kind: String?
    var venue: String?
}

struct APICriterion: Codable {
    var mark: Double?
    var strengths: [String]
    var weaknesses: [String]
}

struct APIQuestion: Codable {
    var question: String
    var refs: String
    var why: String
    var expected: String
    var weak: String
}

struct APIReport: Codable {
    var header: [String: String]
    var criteria: [String: APICriterion]
    var questions: [APIQuestion]
    var substantial: [String]?
    var corrections: [String]
    var summary: String
    var viva: Double?
    var date: String
    var doc_title: String?
}

struct CalEntry: Codable, Identifiable {
    var id: String { exam_id }
    let exam_id: String
    var include: Bool?
    var label: String?
    let date: String
    let proposed: [String: Double?]
    let raw: [String: Double?]
    let final: [String: Double?]
    var note: String?

    static func sum(_ m: [String: Double?]) -> Double { m.values.reduce(0) { $0 + ($1 ?? 0) } }
    var delta: Double { Self.sum(final) - Self.sum(proposed) }
}

struct PanelFeedback: Codable, Equatable {
    let examiners: [String: [String: Double]]
    let chair: [String: Double]
    let notes: [String: String]
    /// Each reader's overall grade, given before the criteria.
    let overall: [String: String]?
    let summary: String?
    let decisions: [String: String]
    let low_confidence: [String]
}

/// Matches a report point to the quote the engine logged for it (same normalization as the engine).
func evidenceKey(_ text: String) -> String {
    var t = text.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
    while let last = t.last, last == "." || last == " " { t.removeLast() }
    return t.split(whereSeparator: \.isWhitespace).joined(separator: " ")
}

/// Exact anchors in a comment that can be found on a PDF page: quoted passages and figure or table labels.
func evidenceAnchors(in text: String) -> [String] {
    let pattern = #"["“]([^"”\n]{12,240})["”]|\b(?:Fig(?:ure)?\.?|Table)\s+[A-Z]?\d+(?:[.\-]\d+)*[a-z]?\b"#
    let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive)
    return (regex?.matches(in: text, range: NSRange(text.startIndex..., in: text)) ?? []).compactMap { match -> String? in
        let quoted = match.range(at: 1)
        let range = quoted.location == NSNotFound ? match.range : quoted
        return Range(range, in: text).map { String(text[$0]) }
    }
}

struct ExamDetail: Codable {
    let id: String
    let state: String
    let pdf: String
    let student: String
    let title: String
    let status: ExamStatus
    let proposed: [String: Double?]
    let applied: [String: Double?]?
    let report: APIReport?
    let page_labels: [String]
    let calibration: CalEntry?
    let scheme: [String: Int]?
    let summary_words: Int?
    let panel: PanelFeedback?
    let grading_scale: GradingScale?
    /// Exact quotes behind the report's strengths and weaknesses, keyed by evidenceKey(point).
    let quotes: [String: String]?
    // Paper reviews
    var kind: String?
    var review: APIReview?
    var venue_form: Venue?
    var form: ReviewForm?
    var panel_review: ReviewPanel?
    var proposed_review: ProposedReview?
    var paper_calibration: PaperCalEntry?

    var isReview: Bool { kind == "review" }
    var markingScheme: Scheme { Scheme(scheme) }

    func proposedMark(_ k: String) -> Int? { (proposed[k] ?? nil).map { Int($0.rounded()) } }
}

struct Phase: Codable, Identifiable, Equatable {
    var id: String { key }
    let key: String
    let label: String
    let state: String
}

struct ProgressInfo: Codable, Equatable {
    let state: String
    let run_kind: String?
    let started: String?
    let phases: [Phase]
    let fraction: Double
}

struct CalibrationSupport: Codable {
    let examples: Int
    let agreeing: Int
    let ready: Bool
}

struct CalibrationInfo: Codable {
    let level: String?
    let dissertation_max: Int?
    let entries: [CalEntry]
    let n: Int
    let offsets: [String: Double]
    let support: [String: CalibrationSupport]?
    let total: Double
}

/// An institution's grading scale: bands as percentages of the maximum, highest first, the last starting at 0.
struct GradingScale: Codable, Equatable {
    struct Band: Codable, Equatable {
        var grade: String
        var min: Int
        var meaning: String
    }
    var name: String
    var bands: [Band]

    var isValid: Bool {
        let mins = bands.map(\.min), grades = bands.map { $0.grade.trimmingCharacters(in: .whitespaces) }
        return (2...10).contains(bands.count) && (mins.first ?? 101) <= 100 && mins.last == 0
            && zip(mins, mins.dropFirst()).allSatisfy { $0 > $1 }
            && grades.allSatisfy { !$0.isEmpty && $0.count <= 24 } && Set(grades).count == grades.count
            && bands.allSatisfy { $0.meaning.count <= 300 }
    }

    /// Upper bound of band i (the next band up starts one point above it).
    func top(_ i: Int) -> Int { i == 0 ? 100 : bands[i - 1].min - 1 }

    func grade(percent: Double) -> String? {
        bands.first { percent.rounded(.down) >= Double($0.min) }?.grade
    }
}

struct SettingsInfo: Codable {
    var examiner_name: String?
    var institution: String?
    var effort: String?
    var model_label: String?
    var claude_version: String?
    var skill_path: String?
    var skill_updated: String?
    var data_path: String?
    var marking_scheme: [String: Int]?
    var summary_words: Int?
    var provider: String?
    var model: String?
    var default_scheme: [String: Int]?
    var grading_scale: GradingScale?
    var grading_presets: [GradingScale]?
    /// The venue of the last paper review, offered first for the next one.
    var venue: String?
}

struct PaperSaveResult: Codable {
    struct Cal: Codable { let n: Int; let shift: Double; let ready: Bool }
    let check_ok: Bool
    let check: String
    let paper_calibration: Cal?
}

struct SaveResult: Codable {
    struct Cal: Codable { let n: Int; let total: Double }
    let check_ok: Bool
    let check: String
    let render_ok: Bool
    let render: String
    let calibration: Cal?
}

enum Level: String, CaseIterable, Identifiable {
    case bsc, msc, phd
    var id: String { rawValue }
    var label: String { ["bsc": "BSc", "msc": "MSc", "phd": "PhD"][rawValue]! }
    var noun: String { self == .phd ? "Thesis" : "Dissertation" }
}

// MARK: - Editable draft

/// One text field's edit buffer (see AppModel.buffer): typing updates only this object, so only its field redraws.
@Observable
final class EditBuffer {
    var text: String
    @ObservationIgnored var pending = false
    @ObservationIgnored let commit: (String) -> Void

    init(text: String, commit: @escaping (String) -> Void) {
        self.text = text
        self.commit = commit
    }
}

struct TextItem: Identifiable, Hashable {
    let id = UUID()
    var text: String
}

struct QuestionDraft: Identifiable, Equatable {
    let id = UUID()
    var question = ""
    var refs = ""
    var why = ""
    var expected = ""
    var weak = ""
}

/// A criterion's comments without its mark, so the comments don't redraw while marks change.
struct CriterionText: Identifiable, Equatable {
    let key: String
    let name: String
    let strengths: [TextItem]
    let weaknesses: [TextItem]
    var id: String { key }
    init(_ c: CriterionDraft) { key = c.spec.key; name = c.spec.name; strengths = c.strengths; weaknesses = c.weaknesses }
}

struct CriterionDraft: Identifiable {
    let spec: CriterionSpec
    var mark: Int
    var strengths: [TextItem]
    var weaknesses: [TextItem]
    var id: String { spec.key }
}

struct ReportDraft {
    var student = "", title = "", degree = "", institution = "", examiner = ""
    var summary = ""
    var criteria: [CriterionDraft] = []
    var questions: [QuestionDraft] = []
    var substantial: [TextItem] = []
    var corrections: [TextItem] = []
    var vivaText = ""
    var vivaMax = 10
    var dissertationMax = 90
    var date = ""
    var docTitle = "MSc Dissertation - Examiner's Report"

    var total: Int { criteria.reduce(0) { $0 + $1.mark } }
    var viva: Double? {
        let t = vivaText.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ",", with: ".")
        guard let v = Double(t), (0...Double(vivaMax)).contains(v) else { return nil }
        return v
    }
    var vivaInvalid: Bool { !vivaText.trimmingCharacters(in: .whitespaces).isEmpty && viva == nil }

    init() {}

    init(_ r: APIReport, scheme: Scheme = Scheme(nil)) {
        vivaMax = scheme.viva
        dissertationMax = scheme.dissertationMax
        student = r.header["student"] ?? ""
        title = r.header["title"] ?? ""
        degree = r.header["degree"] ?? ""
        institution = r.header["institution"] ?? ""
        examiner = r.header["examiner"] ?? ""
        summary = r.summary
        criteria = scheme.specs.map { s in
            let c = r.criteria[s.key]
            return CriterionDraft(spec: s, mark: Int((c?.mark ?? 0).rounded()),
                                  strengths: (c?.strengths ?? []).map { TextItem(text: $0) },
                                  weaknesses: (c?.weaknesses ?? []).map { TextItem(text: $0) })
        }
        questions = r.questions.map { QuestionDraft(question: $0.question, refs: $0.refs, why: $0.why, expected: $0.expected, weak: $0.weak) }
        substantial = (r.substantial ?? []).map { TextItem(text: $0) }
        corrections = r.corrections.map { TextItem(text: $0) }
        if let v = r.viva { vivaText = v == v.rounded() ? String(Int(v)) : String(v) }
        date = r.date
        if let t = r.doc_title, !t.isEmpty { docTitle = t }
    }

    var payload: APIReport {
        APIReport(
            header: ["student": student, "title": title, "degree": degree, "institution": institution, "examiner": examiner],
            criteria: Dictionary(uniqueKeysWithValues: criteria.map {
                ($0.spec.key, APICriterion(mark: Double($0.mark), strengths: $0.strengths.map(\.text), weaknesses: $0.weaknesses.map(\.text)))
            }),
            questions: questions.map { APIQuestion(question: $0.question, refs: $0.refs, why: $0.why, expected: $0.expected, weak: $0.weak) },
            substantial: substantial.map(\.text),
            corrections: corrections.map(\.text),
            summary: summary, viva: viva, date: date, doc_title: docTitle)
    }
}

// MARK: - Paper reviews

/// One option on a venue's scale. Scales list their options best first.
struct VenueOption: Codable, Hashable {
    let value: String
    let label: String
    var tone: String?
    var meaning: String?

    var isNumeric: Bool { Double(value) != nil }
    /// "4: Borderline accept" on numeric scales; just the label on worded ones ("Minor revision").
    var text: String { isNumeric ? "\(value): \(label)" : label }
    /// What a compact control shows: the number on numeric scales, else the label.
    var short: String { isNumeric ? value : label }
}

struct VenueScale: Codable, Hashable {
    let name: String
    let options: [VenueOption]

    func option(_ value: String?) -> VenueOption? { options.first { $0.value == value } }
}

struct VenueScore: Codable, Hashable, Identifiable {
    let key: String
    let name: String
    let options: [VenueOption]
    var id: String { key }

    func option(_ value: String?) -> VenueOption? { options.first { $0.value == value } }
}

struct VenueField: Codable, Hashable {
    let title: String
    let from: [String]
    var guidance: String?
}

struct VenuePolicy: Codable, Hashable {
    let level: String
    let text: String
}

/// A journal or conference and its reviewer form, from Laurea's venue list.
struct Venue: Codable, Hashable, Identifiable {
    let id: String
    let name: String
    let full_name: String
    let kind: String
    var fields: [String]?
    let form: String
    var form_year: Int?
    var anonymity: String?
    let recommendation: VenueScale
    var scores: [VenueScore]?
    var confidence: VenueScale?
    let form_fields: [VenueField]
    let policy: VenuePolicy
    var notes: String?
    var sources: [String]?
    var criteria: [String]?

    var isJournal: Bool { kind == "journal" }
    var scoreList: [VenueScore] { scores ?? [] }
    var isGeneric: Bool { form == "generic" }
}

struct VenuesInfo: Codable {
    let venues: [Venue]
}

struct APIReview: Codable {
    var paper: String
    var venue: String
    var recommendation: String
    var confidence: String
    var summary: String
    var scores: [String: String]
    var strengths: [String]
    var weaknesses: [String]
    var questions: [String]
    var changes: [String: [String]]
    var limitations: String
    var ethics: String
    var confidential: String
}

struct ReviewForm: Codable, Equatable {
    struct Field: Codable, Equatable, Hashable { let title: String; let text: String }
    struct Rating: Codable, Equatable, Hashable { let name: String; let value: String }
    let fields: [Field]
    let ratings: [Rating]
    let confidential: String
    let text: String
}

/// The three reviewers' and the area chair's ratings, as the venue's option values.
struct ReviewPanel: Codable, Equatable {
    let reviewers: [String: [String: String]]
    let chair: [String: String]
    let notes: [String: String]
    let summary: String?
    let decisions: [String: String]
    let low_confidence: [String]
}

struct ProposedReview: Codable, Equatable {
    var recommendation: String?
    var scores: [String: String]?
    var confidence: String?
}

struct PaperCalEntry: Codable, Identifiable {
    var id: String { exam_id }
    let exam_id: String
    var include: Bool?
    var label: String?
    var venue_name: String?
    let date: String
    var proposed: String?
    var final_label: String?
    var steps: Int?
    var delta: Double?
    var note: String?
}

struct PaperCalibrationInfo: Codable {
    let entries: [PaperCalEntry]
    let n: Int
    let shift: Double
    let agreeing: Int
    let ready: Bool
}

struct ReviewDraft {
    var paper = "", venue = ""
    var recommendation = "", confidence = ""
    var scores: [String: String] = [:]
    var summary = ""
    var strengths: [TextItem] = []
    var weaknesses: [TextItem] = []
    var questions: [TextItem] = []
    var major: [TextItem] = []
    var moderate: [TextItem] = []
    var minor: [TextItem] = []
    var limitations = "", ethics = "", confidential = ""

    init() {}

    init(_ r: APIReview) {
        paper = r.paper; venue = r.venue
        recommendation = r.recommendation; confidence = r.confidence; scores = r.scores
        summary = r.summary
        strengths = r.strengths.map { TextItem(text: $0) }
        weaknesses = r.weaknesses.map { TextItem(text: $0) }
        questions = r.questions.map { TextItem(text: $0) }
        major = (r.changes["major"] ?? []).map { TextItem(text: $0) }
        moderate = (r.changes["moderate"] ?? []).map { TextItem(text: $0) }
        minor = (r.changes["minor"] ?? []).map { TextItem(text: $0) }
        limitations = r.limitations; ethics = r.ethics; confidential = r.confidential
    }

    var payload: APIReview {
        APIReview(paper: paper, venue: venue, recommendation: recommendation, confidence: confidence, summary: summary,
                  scores: scores, strengths: strengths.map(\.text), weaknesses: weaknesses.map(\.text),
                  questions: questions.map(\.text),
                  changes: ["major": major.map(\.text), "moderate": moderate.map(\.text), "minor": minor.map(\.text)],
                  limitations: limitations, ethics: ethics, confidential: confidential)
    }
}

// MARK: - Helpers

enum Fmt {
    static func mark(_ x: Double?) -> String {
        guard let x else { return "–" }
        return x == x.rounded() ? String(Int(x)) : String(format: "%.1f", x)
    }
    static func signed(_ x: Double, digits: Int = 0) -> String {
        let s = digits == 0 ? Fmt.mark(x) : String(format: "%.\(digits)f", x)
        return x > 0 ? "+" + s : s
    }
}

/// Printed page references such as "p. 38", "pp. 41-47", "p. iv".
private let pageReferencePattern = try? NSRegularExpression(
    pattern: #"(?<![A-Za-z])(PDF\s+)?pp?\.\s?((?:\d{1,4}|[ivxlc]{1,7}))(?:\s?[-–]\s?(?:\d{1,4}|[ivxlc]{1,7}))?(?![\w])"#,
    options: .caseInsensitive
)

struct PageReference: Hashable {
    let label: String
    let physical: Bool

    var title: String { physical ? "PDF p. \(label)" : "p. \(label)" }
}

func pageRefs(in text: String) -> [PageReference] {
    var out: [PageReference] = []
    let matches = pageReferencePattern?.matches(in: text, range: NSRange(text.startIndex..., in: text)) ?? []
    for m in matches {
        if let range = Range(m.range(at: 2), in: text) {
            let page = PageReference(label: String(text[range]).lowercased(), physical: m.range(at: 1).location != NSNotFound)
            if !out.contains(page) { out.append(page) }
        }
    }
    return Array(out.prefix(5))
}

func wordCount(_ s: String) -> Int {
    s.split { $0.isWhitespace }.filter { $0.contains(where: { $0.isLetter || $0.isNumber }) }.count
}

// MARK: - Skill chat

struct SkillMessage: Codable, Identifiable, Hashable {
    var id: String { (ts ?? "") + role + String(text.prefix(24)) }
    let role: String
    let text: String
    let ts: String?
    let files: [String]?
    let revision: String?
    let diff: String?
    let error: Bool?
}

struct SkillChat: Codable {
    let running: Bool
    let status: String
    let messages: [SkillMessage]
}

struct SkillRevision: Codable, Identifiable, Hashable {
    var id: String { revision }
    let revision: String
    let date: String
    let message: String
    var undoable: Bool?
}

// MARK: - Examination engines (Claude Code / Codex / Gemini CLI)

struct InstallState: Codable, Hashable {
    let state: String
    let message: String?
}

struct EngineStatus: Codable, Hashable {
    let name: String
    let installed: Bool
    let version: String?
    let path: String?
    let installing: InstallState?
    let sign_in: InstallState?
    let signed_in: Bool
}

struct EnginesInfo: Codable {
    let provider: String
    let providers: [String: EngineStatus]
}

struct ModelOption: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let efforts: [String]
}

struct ModelsInfo: Codable {
    let provider: String
    let models: [ModelOption]
    let error: String?
}

enum Engine: String, CaseIterable, Identifiable {
    case claude, openai, gemini
    var id: String { rawValue }
    var label: String { ["claude": "Claude", "openai": "ChatGPT", "gemini": "Gemini"][rawValue]! }
    var tool: String { ["claude": "Claude Code", "openai": "Codex", "gemini": "Gemini CLI"][rawValue]! }
    var icon: String { ["claude": "asterisk", "openai": "circle.hexagongrid", "gemini": "sparkle"][rawValue]! }

    var dataControlsURL: URL {
        URL(string: [
            "claude": "https://claude.ai/settings/data-privacy-controls",
            "openai": "https://help.openai.com/en/articles/7730893-data-controls-in-chatgpt",
            "gemini": "https://developers.google.com/gemini-code-assist/resources/privacy-notice-gemini-code-assist-individuals",
        ][rawValue]!)!
    }

    /// Thoroughness levels offered when the model list doesn't say. Gemini CLI has no reasoning-effort setting,
    /// so it offers Adaptive (which adds focused second opinions) and Standard.
    var defaultEfforts: [String] {
        switch self {
        case .claude: ["low", "medium", "high"]
        case .openai: ["low", "medium", "high", "xhigh"]
        case .gemini: ["medium"]
        }
    }

    static let defaultEffort = "adaptive"  // Standard base pass, Thorough only for disputed criteria
    static let adaptiveEffort = "adaptive"

    static func effortLabel(_ e: String) -> String {
        [adaptiveEffort: "Adaptive", "low": "Light", "medium": "Standard", "high": "Thorough", "xhigh": "Very thorough", "max": "Maximum", "ultra": "Ultra"][e] ?? e.capitalized
    }
}
