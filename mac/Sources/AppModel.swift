import AppKit
import Observation
import SwiftUI
import UniformTypeIdentifiers

enum SidebarItem: Hashable {
    case skill
    case calibration
    case exam(String)
}

struct PDFTarget: Equatable {
    let label: String
    let token = UUID()
}

struct Banner: Equatable {
    enum Kind { case success, warning, failure }
    let kind: Kind
    let text: String
}

@Observable
@MainActor
final class AppModel {
    static let shared = AppModel()
    static var current: AppModel? { shared }
    var settingsSaveTask: Task<Void, Never>?
    var pdfCurrentLabel = ""

    // Engine
    var engineReady = false
    var engineError: String?

    // Sidebar
    var exams: [ExamSummary] = []
    var search = ""
    var saveCount = 0
    var filteredExams: [ExamSummary] {
        let q = search.trimmingCharacters(in: .whitespaces).lowercased()
        guard !q.isEmpty else { return exams }
        return exams.filter { ($0.student + " " + $0.title + " " + $0.pdf).lowercased().contains(q) }
    }
    var selection: SidebarItem?
    var pendingSelection: SidebarItem??
    var showDiscardAlert = false

    // Selected examination
    var detail: ExamDetail?
    var draft: ReportDraft?
    var dirty = false
    var slider: Double = 0
    var sliderBase: [Int]?
    var note = ""
    var banner: Banner?
    var progress: ProgressInfo?
    var isSaving = false
    var newLevel: Level = .msc

    // Panels and sheets
    var showPDF = false
    var pdfTarget: PDFTarget?
    var showRevise = false
    var reviseText = ""
    var showDeleteConfirm = false
    var errorMessage: String?

    // Skill chat
    var skillChat: SkillChat?
    var skillInput = ""
    var skillHistory: [SkillCommit] = []
    var skillSending = false
    private var skillPoll: Task<Void, Never>?

    // Calibration and settings
    var calibrationLevel: Level = .msc
    var calibration: CalibrationInfo?
    var settings = SettingsInfo()

    private var pollTask: Task<Void, Never>?
    private var listTask: Task<Void, Never>?
    let backend = Backend.shared

    init() {}

    // MARK: Lifecycle

    func boot() async {
        do {
            try await backend.start()
            engineReady = true
            SystemIntegration.requestNotifications()
            await refreshList()
            await loadSettings()
            Snapshot.runIfRequested(self)
            listTask = Task { [weak self] in
                while !Task.isCancelled {
                    try? await Task.sleep(for: .seconds(5))
                    await self?.refreshList()
                }
            }
        } catch {
            engineError = error.localizedDescription
        }
    }

    var anyRunning: Bool { exams.contains { $0.state == "running" } }
    var selectedExamID: String? { if case .exam(let id) = selection { return id } else { return nil } }

    // MARK: Sidebar

    func refreshList() async {
        guard engineReady, let list: [ExamSummary] = try? await backend.get("/api/exams") else { return }
        let before = Dictionary(uniqueKeysWithValues: exams.map { ($0.id, $0.state) })
        for e in list where before[e.id] == "running" && e.state != "running" { SystemIntegration.notifyReady(e) }
        if list != exams { exams = list }
        SystemIntegration.updateDockBadge(running: list.filter { $0.state == "running" }.count)
    }

    /// Called by the sidebar's selection binding; asks before throwing away edits.
    func requestSelection(_ item: SidebarItem?) {
        guard item != selection else { return }
        if dirty {
            pendingSelection = .some(item)
            showDiscardAlert = true
            return
        }
        Task { await select(item) }
    }

    func confirmDiscard(save: Bool) async {
        if save { await self.save(); if dirty { return } }
        dirty = false
        if case .some(let item) = pendingSelection { await select(item) }
        pendingSelection = nil
    }

    func select(_ item: SidebarItem?) async {
        selection = item
        pollTask?.cancel()
        detail = nil; draft = nil; dirty = false; banner = nil; progress = nil
        slider = 0; sliderBase = nil; showPDF = false
        switch item {
        case .exam(let id): await load(id)
        case .calibration: await loadCalibration()
        case .skill: await loadSkillChat(); await loadSkillHistory()
        case nil: break
        }
    }

    func load(_ id: String, keepBanner: Bool = false) async {
        do {
            let d: ExamDetail = try await backend.get("/api/exams/\(id)")
            guard selectedExamID == id else { return }
            detail = d
            draft = d.report.map { ReportDraft($0, scheme: d.markingScheme) }
            note = d.calibration?.note ?? ""
            dirty = false
            slider = 0; sliderBase = nil
            if !keepBanner { banner = nil }
            if let l = d.status.level, let lv = Level(rawValue: l) { newLevel = lv }
            if d.state == "running" { startPolling(id) }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: Import

    func chooseAndImport() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.pdf]
        panel.allowsMultipleSelection = true
        panel.message = "Choose dissertation PDFs to examine"
        panel.prompt = "Add"
        if panel.runModal() == .OK {
            Task { for url in panel.urls { await importPDF(url) } }
        }
    }

    func importPDF(_ url: URL) async {
        guard url.pathExtension.lowercased() == "pdf", let data = try? Data(contentsOf: url) else {
            errorMessage = "\(url.lastPathComponent) is not a readable PDF."
            return
        }
        do {
            let name = url.lastPathComponent.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? "dissertation.pdf"
            let d = try await backend.data("POST", "/api/exams", body: data, headers: ["X-Filename": name], timeout: 300)
            let e = try JSONDecoder().decode(ExamSummary.self, from: d)
            await refreshList()
            requestSelection(.exam(e.id))
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: Runs

    func examine() async {
        guard let id = selectedExamID else { return }
        struct Body: Encodable { let level: String }
        do {
            let _: OK = try await backend.send("POST", "/api/exams/\(id)/examine", Body(level: newLevel.rawValue))
            await refreshList()
            await load(id)
            startPolling(id)
        } catch { errorMessage = error.localizedDescription }
    }

    func stopRun() async {
        guard let id = selectedExamID else { return }
        try? await backend.post("/api/exams/\(id)/cancel")
        await refreshList()
        await load(id)
    }

    func revise() async {
        guard let id = selectedExamID else { return }
        struct Body: Encodable { let instruction: String }
        let text = reviseText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        do {
            let _: OK = try await backend.send("POST", "/api/exams/\(id)/revise", Body(instruction: text))
            reviseText = ""
            await refreshList()
            await load(id)
            startPolling(id)
        } catch { errorMessage = error.localizedDescription }
    }

    private func startPolling(_ id: String) {
        pollTask?.cancel()
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                if let p: ProgressInfo = try? await self.backend.get("/api/exams/\(id)/progress?since=999999") {
                    guard self.selectedExamID == id else { return }
                    self.progress = p
                    if p.state != "running" {
                        await self.refreshList()
                        await self.load(id)
                        return
                    }
                }
                try? await Task.sleep(for: .seconds(1.5))
            }
        }
    }

    // MARK: Editing

    func markEdited() { dirty = true }

    func setMark(_ index: Int, _ value: Int) {
        guard var d = draft else { return }
        d.criteria[index].mark = max(0, min(d.criteria[index].spec.max, value))
        draft = d
        slider = 0; sliderBase = nil
        dirty = true
    }

    func applySlider(_ value: Double) {
        guard var d = draft else { return }
        if sliderBase == nil { sliderBase = d.criteria.map(\.mark) }
        slider = value.rounded()
        let marks = distribute(sliderBase!, delta: Int(slider), maxima: d.criteria.map(\.spec.max))
        for i in d.criteria.indices { d.criteria[i].mark = marks[i] }
        draft = d
        dirty = true
    }

    var proposedTotal: Int? {
        guard let d = detail else { return nil }
        let ps = CRITERIA.map { d.proposedMark($0.key) }
        return ps.contains(where: { $0 == nil }) ? nil : ps.compactMap { $0 }.reduce(0, +)
    }

    func openPDF(at label: String? = nil) {
        showPDF = true
        if let label { pdfTarget = PDFTarget(label: label) }
    }

    var pdfURL: URL? {
        guard let d = detail else { return nil }
        return backend.examsDir.appendingPathComponent(d.id).appendingPathComponent(d.pdf)
    }

    var reportDocxURL: URL? {
        guard let d = detail else { return nil }
        let stem = (d.pdf as NSString).deletingPathExtension
        let u = backend.examsDir.appendingPathComponent(d.id).appendingPathComponent("\(stem)_examiner_report.docx")
        return FileManager.default.fileExists(atPath: u.path) ? u : nil
    }

    // MARK: Save / export

    var canSave: Bool { draft != nil && dirty && !isSaving }

    func save() async {
        guard let id = selectedExamID, var d = draft else { return }
        if d.vivaInvalid { errorMessage = "The viva mark must be a number from 0 to \(d.vivaMax)."; return }
        if let l = Level(rawValue: detail?.status.level ?? "msc") { d.docTitle = "\(l.label) \(l.noun) - Examiner's Report" }
        struct Body: Encodable { let report: APIReport; let note: String }
        isSaving = true
        defer { isSaving = false }
        do {
            let r: SaveResult = try await backend.send("PUT", "/api/exams/\(id)/report", Body(report: d.payload, note: note))
            let issues = r.check.split(separator: "\n").filter { $0.hasPrefix("ERROR") || $0.hasPrefix("WARNING") }
                .map { $0.replacingOccurrences(of: "ERROR: ", with: "").replacingOccurrences(of: "WARNING: ", with: "") }
            var text = "Saved and Word document updated."
            if let c = r.calibration { text += " Learned \(Level(rawValue: detail?.status.level ?? "msc")?.label ?? "") offset: \(Fmt.signed(c.total, digits: 1)) from \(c.n) examination\(c.n == 1 ? "" : "s")." }
            if !r.render_ok {
                banner = Banner(kind: .failure, text: "Saved, but the Word document could not be produced.\n" + r.render)
            } else if !r.check_ok {
                banner = Banner(kind: .failure, text: "Saved, but the report checker found problems:\n• " + issues.joined(separator: "\n• "))
            } else {
                banner = Banner(kind: issues.isEmpty ? .success : .warning, text: issues.isEmpty ? text : text + "\n• " + issues.joined(separator: "\n• "))
            }
            dirty = false
            saveCount += 1
            await load(id, keepBanner: true)
            await refreshList()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func exportWord() {
        if dirty { errorMessage = "Save your changes first, so the Word document includes them."; return }
        guard let src = reportDocxURL else { errorMessage = "There is no Word document yet."; return }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [UTType(filenameExtension: "docx") ?? .data]
        let who = (draft?.student.isEmpty == false ? draft!.student : "Dissertation").replacingOccurrences(of: "/", with: "-")
        panel.nameFieldStringValue = "\(who) - Examiner's Report.docx"
        panel.canCreateDirectories = true
        if panel.runModal() == .OK, let dest = panel.url {
            try? FileManager.default.removeItem(at: dest)
            do { try FileManager.default.copyItem(at: src, to: dest); NSWorkspace.shared.activateFileViewerSelecting([dest]) }
            catch { errorMessage = error.localizedDescription }
        }
    }

    func revealInFinder() {
        guard let d = detail else { return }
        let folder = backend.examsDir.appendingPathComponent(d.id)
        NSWorkspace.shared.activateFileViewerSelecting([reportDocxURL ?? folder.appendingPathComponent(d.pdf)])
    }

    func deleteSelected() async {
        guard let id = selectedExamID else { return }
        do {
            try await backend.post("/api/exams/\(id)/delete")
            dirty = false
            await select(nil)
            await refreshList()
        } catch { errorMessage = error.localizedDescription }
    }

    // MARK: Calibration

    func loadCalibration() async {
        calibration = try? await backend.get("/api/calibration?level=\(calibrationLevel.rawValue)")
    }

    func setInclude(_ examID: String, _ include: Bool) async {
        struct Body: Encodable { let include: Bool }
        let _: OK? = try? await backend.send("PUT", "/api/calibration/\(examID)", Body(include: include))
        await loadCalibration()
    }

    func openCalibrationNotes() {
        NSWorkspace.shared.open(backend.calibrationNotes)
    }

    // MARK: Skill chat

    var skillBusy: Bool { skillSending || (skillChat?.running ?? false) }

    func loadSkillChat() async {
        if let c: SkillChat = try? await backend.get("/api/skill/chat") {
            skillChat = c
            if c.running { startSkillPolling() }
        }
    }

    func loadSkillHistory() async {
        skillHistory = (try? await backend.get("/api/skill/history")) ?? []
    }

    func sendSkillMessage(_ text: String? = nil) async {
        let msg = (text ?? skillInput).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !msg.isEmpty, !skillBusy else { return }
        struct Body: Encodable { let message: String }
        skillSending = true
        defer { skillSending = false }
        do {
            let _: OK = try await backend.send("POST", "/api/skill/chat", Body(message: msg))
            skillInput = ""
            await loadSkillChat()
            startSkillPolling()
        } catch { errorMessage = error.localizedDescription }
    }

    private func startSkillPolling() {
        skillPoll?.cancel()
        skillPoll = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1.2))
                guard let self, let c: SkillChat = try? await self.backend.get("/api/skill/chat") else { continue }
                self.skillChat = c
                if !c.running {
                    await self.loadSkillHistory()
                    await self.loadSettings()
                    return
                }
            }
        }
    }

    func stopSkill() async { try? await backend.post("/api/skill/chat/stop") }

    func newSkillConversation() async {
        try? await backend.post("/api/skill/chat/new")
        await loadSkillChat()
    }

    func undoSkillChange(_ commit: String) async {
        struct Body: Encodable { let commit: String }
        do {
            let _: OK = try await backend.send("POST", "/api/skill/undo", Body(commit: commit))
            await loadSkillChat()
            await loadSkillHistory()
        } catch { errorMessage = error.localizedDescription }
    }

    // MARK: Examination engines

    var engines: EnginesInfo?
    var models: [String: ModelsInfo] = [:]
    var loadingModels: Set<String> = []
    private var enginePoll: Task<Void, Never>?

    var activeEngine: Engine { Engine(rawValue: settings.provider ?? "claude") ?? .claude }

    func loadEngines() async {
        engines = try? await backend.get("/api/assistant")
        for e in Engine.allCases where engines?.providers[e.rawValue]?.signed_in == true && models[e.rawValue] == nil {
            await loadModels(e)
        }
    }

    func loadModels(_ e: Engine, refresh: Bool = false) async {
        loadingModels.insert(e.rawValue)
        defer { loadingModels.remove(e.rawValue) }
        if let m: ModelsInfo = try? await backend.get("/api/models?provider=\(e.rawValue)\(refresh ? "&refresh=1" : "")") {
            models[e.rawValue] = m
        }
    }

    /// Model and thoroughness actually used for `e` (falls back to the recommended model and its default).
    func currentModel(for e: Engine) -> ModelOption? {
        let list = models[e.rawValue]?.models ?? []
        if e == activeEngine, let id = settings.model, !id.isEmpty, let m = list.first(where: { $0.id == id }) { return m }
        return list.first(where: \.recommended) ?? list.first
    }

    func setEngine(_ e: Engine, model: String? = nil, effort: String? = nil) async {
        var m = model
        var eff = effort ?? settings.effort ?? "high"
        if m == nil {
            if e != activeEngine { m = "" } else { m = settings.model ?? "" }
        }
        let option = (models[e.rawValue]?.models ?? []).first { $0.id == m } ?? (models[e.rawValue]?.models ?? []).first(where: \.recommended)
        if let option, !option.efforts.isEmpty, !option.efforts.contains(eff) { eff = option.default_effort ?? option.efforts.last! }
        struct Body: Encodable { let provider, model, effort: String }
        if let r: SettingsInfo = try? await backend.send("PUT", "/api/settings", Body(provider: e.rawValue, model: m ?? "", effort: eff)) {
            settings = r
        }
    }

    func installEngine(_ e: Engine) async {
        try? await backend.post("/api/engines/\(e.rawValue)/install")
        watchEngines()
    }

    /// Opens Terminal with the engine's own sign-in command, then watches until sign-in completes.
    func signIn(_ e: Engine) {
        guard let cmd = engines?.providers[e.rawValue]?.login_command else { return }
        let escaped = cmd.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
        let script = "tell application \"Terminal\"\nactivate\ndo script \"\(escaped)\"\nend tell"
        var err: NSDictionary?
        NSAppleScript(source: script)?.executeAndReturnError(&err)
        if err != nil { errorMessage = "Couldn't open Terminal to sign in. Run this in Terminal: \(cmd)" }
        watchEngines()
    }

    private func watchEngines() {
        enginePoll?.cancel()
        enginePoll = Task { [weak self] in
            for _ in 0..<200 {
                try? await Task.sleep(for: .seconds(3))
                guard let self, !Task.isCancelled else { return }
                let before = self.engines
                await self.loadEngines()
                let busy = self.engines?.providers.values.contains { $0.installing?.state == "running" } ?? false
                let changed = before?.providers != self.engines?.providers
                if changed { for e in Engine.allCases where self.engines?.providers[e.rawValue]?.signed_in == true { await self.loadModels(e, refresh: true) } }
                if !busy && changed { return }
            }
        }
    }

    // MARK: Settings

    func loadSettings() async {
        if let s: SettingsInfo = try? await backend.get("/api/settings") { settings = s }
    }

    func saveSettings() async {
        struct Body: Encodable { let examiner_name, institution, degree_default, effort: String; let marking_scheme: [String: Int]? }
        let s = settings
        let scheme = s.marking_scheme.flatMap { Scheme.isValid($0) ? $0 : nil }
        let r: SettingsInfo? = try? await backend.send("PUT", "/api/settings",
            Body(examiner_name: s.examiner_name ?? "", institution: s.institution ?? "", degree_default: s.degree_default ?? "",
                 effort: s.effort ?? "high", marking_scheme: scheme))
        if let r {
            // keep an in-progress (not yet valid) weights edit on screen
            let editing = settings.marking_scheme
            settings = r
            if let editing, !Scheme.isValid(editing) { settings.marking_scheme = editing }
        }
    }
}
