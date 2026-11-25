import Foundation

// MARK: - Fixed marking scheme

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

    var displayName: String { student.isEmpty ? (pdf as NSString).deletingPathExtension.replacingOccurrences(of: "_", with: " ") : student }
}

struct ExamStatus: Codable {
    var state: String?
    var pdf: String?
    var original_name: String?
    var message: String?
    var run_kind: String?
    var started: String?
    var level: String?
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
    let markdown: String?
    let page_labels: [String]
    let calibration: CalEntry?

    func proposedMark(_ k: String) -> Int? { (proposed[k] ?? nil).map { Int($0.rounded()) } }
}

struct Phase: Codable, Identifiable {
    var id: String { key }
    let key: String
    let label: String
    let state: String
}

struct ProgressInfo: Codable {
    let next: Int
    let state: String
    let run_kind: String?
    let started: String?
    let phases: [Phase]
    let fraction: Double
}

struct CalibrationInfo: Codable {
    let level: String?
    let entries: [CalEntry]
    let n: Int
    let offsets: [String: Double]
    let total: Double
}

struct SettingsInfo: Codable {
    var examiner_name: String?
    var institution: String?
    var degree_default: String?
    var effort: String?
    var model_label: String?
    var claude_version: String?
    var skill_path: String?
    var skill_updated: String?
    var data_path: String?
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

struct TextItem: Identifiable, Hashable {
    let id = UUID()
    var text: String
}

struct QuestionDraft: Identifiable {
    let id = UUID()
    var question = ""
    var refs = ""
    var why = ""
    var expected = ""
    var weak = ""
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
    var corrections: [TextItem] = []
    var vivaText = ""
    var date = ""
    var docTitle = "MSc Dissertation - Examiner's Report"

    var total: Int { criteria.reduce(0) { $0 + $1.mark } }
    var viva: Double? {
        let t = vivaText.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ",", with: ".")
        guard let v = Double(t), (0...10).contains(v) else { return nil }
        return v
    }
    var vivaInvalid: Bool { !vivaText.trimmingCharacters(in: .whitespaces).isEmpty && viva == nil }

    init() {}

    init(_ r: APIReport) {
        student = r.header["student"] ?? ""
        title = r.header["title"] ?? ""
        degree = r.header["degree"] ?? ""
        institution = r.header["institution"] ?? ""
        examiner = r.header["examiner"] ?? ""
        summary = r.summary
        criteria = CRITERIA.map { s in
            let c = r.criteria[s.key]
            return CriterionDraft(spec: s, mark: Int((c?.mark ?? 0).rounded()),
                                  strengths: (c?.strengths ?? []).map { TextItem(text: $0) },
                                  weaknesses: (c?.weaknesses ?? []).map { TextItem(text: $0) })
        }
        questions = r.questions.map { QuestionDraft(question: $0.question, refs: $0.refs, why: $0.why, expected: $0.expected, weak: $0.weak) }
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
            corrections: corrections.map(\.text),
            summary: summary, viva: viva, date: date, doc_title: docTitle)
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
func pageRefs(in text: String) -> [String] {
    let pattern = #"(?<![A-Za-z])pp?\.\s?((?:\d{1,4}|[ivxlc]{1,7}))(?:\s?[-–]\s?(?:\d{1,4}|[ivxlc]{1,7}))?(?![\w])"#
    guard let re = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return [] }
    var out: [String] = []
    for m in re.matches(in: text, range: NSRange(text.startIndex..., in: text)) {
        if let r = Range(m.range(at: 1), in: text) {
            let s = String(text[r])
            if !out.contains(s) { out.append(s) }
        }
    }
    return Array(out.prefix(5))
}

func wordCount(_ s: String) -> Int {
    s.split { $0.isWhitespace }.filter { $0.contains(where: { $0.isLetter || $0.isNumber }) }.count
}

/// Spread `delta` whole marks over criteria in proportion to their maximum, one mark at a time.
func distribute(_ base: [Int], delta: Int) -> [Int] {
    var out = base
    var given = Array(repeating: 0, count: base.count)
    let sign = delta >= 0 ? 1 : -1
    for _ in 0..<abs(delta) {
        var best: Int? = nil
        var bestGap = -Double.infinity
        for (i, spec) in CRITERIA.enumerated() {
            let room = sign > 0 ? out[i] < spec.max : out[i] > 0
            guard room else { continue }
            let gap = Double(abs(delta)) * Double(spec.max) / 90.0 - Double(abs(given[i]))
            if gap > bestGap { bestGap = gap; best = i }
        }
        guard let b = best else { break }
        out[b] += sign
        given[b] += sign
    }
    return out
}

// MARK: - Skill chat

struct SkillMessage: Codable, Identifiable, Hashable {
    var id: String { (ts ?? "") + role + String(text.prefix(24)) }
    let role: String
    let text: String
    let ts: String?
    let files: [String]?
    let commit: String?
    let diff: String?
    let error: Bool?
}

struct SkillChat: Codable {
    let running: Bool
    let status: String
    let messages: [SkillMessage]
}

struct SkillCommit: Codable, Identifiable, Hashable {
    var id: String { commit }
    let commit: String
    let date: String
    let message: String
}
