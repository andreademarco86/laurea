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
    let reference: PageReference
    let highlights: [String]
    /// The comment the page was opened from; used to find the best-matching passage when no exact anchor exists.
    var context: String = ""
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
    var draft: ReportDraft? { didSet { draftRevision &+= 1 } }
    /// Bumped on every change to the draft, so a finishing save can tell whether newer edits exist.
    @ObservationIgnored private(set) var draftRevision = 0

    // MARK: Text editing buffers
    // Typing goes into a small per-field buffer, so a keystroke redraws only that field instead of the whole
    // report. The draft is updated when typing pauses, and before anything reads it (save, export, revise, switch).
    @ObservationIgnored private var buffers: [String: EditBuffer] = [:]
    @ObservationIgnored private var commitTask: Task<Void, Never>?

    func buffer(_ key: String, _ binding: Binding<String>) -> EditBuffer {
        if let b = buffers[key] { return b }
        let b = EditBuffer(text: binding.wrappedValue) { binding.wrappedValue = $0 }
        buffers[key] = b
        return b
    }

    /// A binding into one part of the draft, for sections that redraw only when their own content changes.
    func draftBinding<T>(_ path: WritableKeyPath<ReportDraft, T>) -> Binding<T> {
        Binding(get: { [unowned self] in (self.draft ?? ReportDraft())[keyPath: path] },
                set: { [unowned self] value in
                    guard self.draft != nil else { return }
                    self.draft![keyPath: path] = value
                    self.dirty = true
                })
    }

    /// Strengths or weaknesses of criterion `index`, safe while the draft is being replaced.
    func criterionItems(_ index: Int, strengths: Bool) -> Binding<[TextItem]> {
        Binding(get: { [unowned self] in
                    guard let d = self.draft, d.criteria.indices.contains(index) else { return [] }
                    return strengths ? d.criteria[index].strengths : d.criteria[index].weaknesses
                },
                set: { [unowned self] items in
                    guard self.draft?.criteria.indices.contains(index) == true else { return }
                    if strengths { self.draft!.criteria[index].strengths = items } else { self.draft!.criteria[index].weaknesses = items }
                    self.dirty = true
                })
    }

    func edited(_ b: EditBuffer) {
        b.pending = true
        draftRevision &+= 1
        if !dirty { dirty = true }
        commitTask?.cancel()
        commitTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(600))
            guard !Task.isCancelled else { return }
            self?.commitEdits()
        }
    }

    /// Write any buffered typing into the draft.
    func commitEdits() {
        commitTask?.cancel()
        commitTask = nil
        for b in buffers.values where b.pending {
            b.pending = false
            b.commit(b.text)
        }
    }

    private func resetBuffers() {
        commitTask?.cancel()
        commitTask = nil
        buffers = [:]
    }
    var dirty = false
    var slider: Double = 0          // position, -1 (harshest) ... +1 (most generous)
    var sliderBase: [Int]?
    var sliderDelta = 0             // marks added or removed by the slider
    var note = "" { didSet { draftRevision &+= 1 } }
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
    var deleteTargetID: String?

    /// Ask before moving an examination (default: the selected one) to the Trash.
    func confirmDelete(_ id: String? = nil) {
        guard let target = id ?? selectedExamID else { return }
        if exams.first(where: { $0.id == target })?.state == "running" {
            errorMessage = "Stop this examination before moving it to the Trash."
            return
        }
        deleteTargetID = target
        showDeleteConfirm = true
    }

    var deleteTargetName: String {
        guard let id = deleteTargetID, let e = exams.first(where: { $0.id == id }) else { return "this examination" }
        return e.displayName
    }
    var errorMessage: String?

    // Skill chat
    var skillChat: SkillChat?
    var skillInput = ""
    var skillHistory: [SkillRevision] = []
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
            await loadSettings()
            Task { await checkSetupNeeded() }
            await refreshList()
            Snapshot.runIfRequested(self)
            listTask = Task { [weak self] in
                while !Task.isCancelled {
                    try? await Task.sleep(for: .seconds(5))
                    if let self, self.anyRunning { await self.refreshList() }
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
        // keep the main screen in step with the sidebar (e.g. a run that started or finished elsewhere)
        if let id = selectedExamID, let d = detail, let e = list.first(where: { $0.id == id }), e.state != d.state, !dirty {
            await load(id, keepBanner: true)
            if e.state == "running" { startPolling(id) }
        }
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
        commitEdits()
        if save { await self.save(); if dirty { return } }
        dirty = false
        if case .some(let item) = pendingSelection { await select(item) }
        pendingSelection = nil
    }

    func select(_ item: SidebarItem?) async {
        resetBuffers()
        selection = item
        pollTask?.cancel()
        detail = nil; draft = nil; dirty = false; banner = nil; progress = nil
        slider = 0; sliderBase = nil; sliderDelta = 0; showPDF = false
        pdfTarget = nil
        pdfCurrentLabel = ""
        switch item {
        case .exam(let id): await load(id)
        case .calibration: await loadCalibration()
        case .skill: await loadSkillChat(); await loadSkillHistory()
        case nil: break
        }
    }

    /// `ifRevision`: apply the fetched report only if the draft has not changed since then (no edit is overwritten).
    func load(_ id: String, keepBanner: Bool = false, ifRevision: Int? = nil) async {
        do {
            let d: ExamDetail = try await backend.get("/api/exams/\(id)")
            guard selectedExamID == id else { return }
            if let r = ifRevision, draftRevision != r { return }
            detail = d
            resetBuffers()
            draft = d.report.map { ReportDraft($0, scheme: d.markingScheme) }
            dateOptOut = d.status.date_opt_out ?? false
            note = d.calibration?.note ?? ""
            dirty = false
            slider = 0; sliderBase = nil; sliderDelta = 0
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
        do {
            let body = ["provider": activeEngine.rawValue, "level": newLevel.rawValue]
            let _: OK = try await backend.send("POST", "/api/exams/\(id)/examine", body)
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
        commitEdits()
        guard let id = selectedExamID else { return }
        let text = reviseText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        do {
            let body = ["provider": activeEngine.rawValue, "instruction": text]
            let _: OK = try await backend.send("POST", "/api/exams/\(id)/revise", body)
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
                    if self.progress != p { self.progress = p }
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
        slider = 0; sliderBase = nil; sliderDelta = 0
        dirty = true
    }

    func applySlider(_ value: Double) {
        guard var d = draft else { return }
        if sliderBase == nil { sliderBase = d.criteria.map(\.mark) }
        slider = max(-1, min(1, value))
        // Progressive response: fine control near the centre, reaching 0 or full marks at the ends.
        let base = sliderBase!
        let room = slider >= 0 ? Double(d.dissertationMax - base.reduce(0, +)) : Double(base.reduce(0, +))
        let delta = Int((slider.sign == .minus ? -1 : 1) * pow(abs(slider), 2.2) * room)
        sliderDelta = delta
        let marks = distribute(base, delta: delta, maxima: d.criteria.map(\.spec.max))
        for i in d.criteria.indices { d.criteria[i].mark = marks[i] }
        draft = d
        dirty = true
    }

    var proposedTotal: Int? {
        guard let d = detail else { return nil }
        let ps = CRITERIA.map { d.proposedMark($0.key) }
        return ps.contains(where: { $0 == nil }) ? nil : ps.compactMap { $0 }.reduce(0, +)
    }

    func openPDF(at reference: PageReference? = nil, highlighting highlights: [String] = [], context: String = "") {
        showPDF = true
        if let reference { pdfTarget = PDFTarget(reference: reference, highlights: highlights, context: context) }
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

    /// Saves the report; returns true when it was stored. The Word report is produced only at export.
    @discardableResult
    func save() async -> Bool {
        commitEdits()
        guard let id = selectedExamID, var d = draft else { return false }
        let revision = draftRevision
        if d.vivaInvalid { errorMessage = "The viva mark must be a number from 0 to \(d.vivaMax)."; return false }
        if let l = Level(rawValue: detail?.status.level ?? "msc") { d.docTitle = "\(l.label) \(l.noun) - Examiner's Report" }
        struct Body: Encodable { let report: APIReport; let note: String; let date_opt_out: Bool }
        isSaving = true
        defer { isSaving = false }
        do {
            let r: SaveResult = try await backend.send("PUT", "/api/exams/\(id)/report", Body(report: d.payload, note: note, date_opt_out: dateOptOut))
            let issues = r.check.split(separator: "\n").filter { $0.hasPrefix("ERROR") || $0.hasPrefix("WARNING") }
                .map { $0.replacingOccurrences(of: "ERROR: ", with: "").replacingOccurrences(of: "WARNING: ", with: "") }
            var text = "Saved."
            if let c = r.calibration { text += " Learned \(Level(rawValue: detail?.status.level ?? "msc")?.label ?? "") offset: \(Fmt.signed(c.total, digits: 1)) from \(c.n) examination\(c.n == 1 ? "" : "s")." }
            if !r.render_ok {
                banner = Banner(kind: .failure, text: "Saved, but the Word document could not be produced.\n" + r.render)
            } else if !r.check_ok {
                banner = Banner(kind: .failure, text: "Saved, but the report checker found problems:\n• " + issues.joined(separator: "\n• "))
            } else {
                banner = Banner(kind: issues.isEmpty ? .success : .warning, text: issues.isEmpty ? text : text + "\n• " + issues.joined(separator: "\n• "))
            }
            // Only settle the state of the examination and draft version this save started from.
            guard selectedExamID == id else { await refreshList(); return r.render_ok }
            if draftRevision != revision {
                banner = Banner(kind: .warning, text: "Saved, but you made changes while saving. Save again to include them.")
                await refreshList()
                return false
            }
            dirty = false
            saveCount += 1
            await load(id, keepBanner: true, ifRevision: draftRevision)
            await refreshList()
            return r.render_ok
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    /// Why the report can't be exported yet, or nil. The Word report comes last: after the review and the viva,
    /// signed, with the viva and final marks.
    var exportBlocker: String? {
        guard let d = draft else { return "There is no report to export yet." }
        if d.viva == nil { return "Add the viva mark after the oral, then export." }
        if !hasSignature { return "Add your signature in Settings → General, then export." }
        return nil
    }

    /// Exporting is the examiner's confirmation of the final report, so it saves any edits, dates an undated report
    /// (unless the examiner turned the date off), then produces the signed Word report with the viva and final marks.
    /// Everything is pinned to the examination selected when export began.
    func exportWord() async {
        commitEdits()
        guard let id = selectedExamID, let exam = detail, exam.id == id, var d = draft else { return }
        if let blocker = exportBlocker { errorMessage = blocker; return }
        if d.date.trimmingCharacters(in: .whitespaces).isEmpty && !dateOptOut {
            let f = DateFormatter(); f.dateFormat = "dd/MM/yyyy"
            d.date = f.string(from: .now)
            draft = d
            dirty = true
        }
        if dirty {
            let saved = await save()
            guard selectedExamID == id else { errorMessage = "The selection changed during export. Export again."; return }
            guard saved else {
                errorMessage = "The report could not be saved, so nothing was exported. Check the message above and try again."
                return
            }
        }
        struct Exported: Decodable { let path: String }
        let exported: Exported
        do {
            exported = try await backend.send("POST", "/api/exams/\(id)/export", [String: String]())
        } catch {
            errorMessage = error.localizedDescription
            return
        }
        guard selectedExamID == id else { errorMessage = "The selection changed during export. Export again."; return }
        // The Word report is saved with the examination; show it in Finder.
        let url = URL(fileURLWithPath: exported.path)
        banner = Banner(kind: .success, text: "Word report exported: \(url.lastPathComponent)")
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    func revealInFinder() {
        guard let d = detail else { return }
        let folder = backend.examsDir.appendingPathComponent(d.id)
        NSWorkspace.shared.activateFileViewerSelecting([reportDocxURL ?? folder.appendingPathComponent(d.pdf)])
    }

    func deleteSelected() async {
        guard let id = deleteTargetID ?? selectedExamID else { return }
        deleteTargetID = nil
        do {
            try await backend.post("/api/exams/\(id)/delete")
            if id == selectedExamID {
                dirty = false
                await select(nil)
            }
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
        skillSending = true
        defer { skillSending = false }
        do {
            let body = ["provider": activeEngine.rawValue, "message": msg]
            let _: OK = try await backend.send("POST", "/api/skill/chat", body)
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

    func undoSkillChange(_ revision: String) async {
        do {
            let _: OK = try await backend.send("POST", "/api/skill/undo", ["revision": revision])
            await loadSkillChat()
            await loadSkillHistory()
        } catch { errorMessage = error.localizedDescription }
    }

    // MARK: Report editor view state (lives here: the app builds without the SwiftUI macro plugin)

    var vivaExpanded = true
    var summaryExpanded = true
    var criteriaExpanded = true
    /// The Settings tab to show: "general", "marking" or "engine".
    var settingsTab = "general"
    var correctionsExpanded = true

    /// The examining standards in use: taught ones in the data folder, else the app's own.
    var standardsURL: URL? { settings.skill_path.map { URL(fileURLWithPath: $0) } }

    /// The examiner turned the declaration date off for this examination: export must not add one.
    var dateOptOut = false

    // MARK: Setup Assistant and signature

    var showSetup = false
    var setupStep = 0
    var signatureVersion = 0
    var signatureDropping = false

    var setupCompletedBefore: Bool { UserDefaults.standard.bool(forKey: "setupComplete") }
    var activeEngineReady: Bool {
        engines?.providers[activeEngine.rawValue]?.signed_in == true
    }
    var hasSignature: Bool { _ = signatureVersion; return FileManager.default.fileExists(atPath: backend.signatureURL.path) }
    var signatureImage: NSImage? { _ = signatureVersion; return NSImage(contentsOf: backend.signatureURL) }

    func openSetup() {
        setupStep = 0
        showSetup = true
        Task { await loadEngines() }
    }

    func completeSetup() {
        UserDefaults.standard.set(true, forKey: "setupComplete")
        showSetup = false
        setupStep = 0
    }

    /// Shown on first launch, or when the chosen engine is not ready to examine.
    func checkSetupNeeded() async {
        await loadEngines()
        if ProcessInfo.processInfo.environment["DE_SNAPSHOT_DIR"] != nil { return }
        if !setupCompletedBefore || !activeEngineReady {
            setupStep = setupCompletedBefore ? 1 : 0
            showSetup = true
        }
    }

    func chooseSignature() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.png, .jpeg, .tiff, .heic, .image]
        panel.message = "Choose an image of your signature (ideally on a white or transparent background)"
        panel.prompt = "Use Signature"
        if panel.runModal() == .OK, let url = panel.url { saveSignature(from: url) }
    }

    func saveSignature(from url: URL) {
        guard let img = NSImage(contentsOf: url), let tiff = img.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff), let png = rep.representation(using: .png, properties: [:]) else {
            errorMessage = "That file isn't an image Laurea can read. Try a PNG or JPEG."
            return
        }
        do {
            try FileManager.default.createDirectory(at: backend.signatureURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try png.write(to: backend.signatureURL, options: .atomic)
            signatureVersion += 1
        } catch {
            errorMessage = "Couldn't save the signature: \(error.localizedDescription)"
        }
    }

    // MARK: Examination engines

    var engines: EnginesInfo?
    var models: [String: ModelsInfo] = [:]
    var loadingModels: Set<String> = []
    private var enginePoll: Task<Void, Never>?

    var activeEngine: Engine { Engine(rawValue: settings.provider ?? "claude") ?? .claude }

    func loadEngines() async {
        if let loaded: EnginesInfo = try? await backend.get("/api/assistant") {
            for e in Engine.allCases where loaded.providers[e.rawValue]?.signed_in != true {
                models[e.rawValue] = nil
            }
            engines = loaded
        }
        await loadModels()
    }

    func loadModels() async {
        let e = activeEngine
        guard engines?.providers[e.rawValue]?.signed_in == true,
              models[e.rawValue] == nil, !loadingModels.contains(e.rawValue) else { return }
        loadingModels.insert(e.rawValue)
        defer { loadingModels.remove(e.rawValue) }
        if let result: ModelsInfo = try? await backend.get("/api/models?provider=\(e.rawValue)"),
           e == activeEngine, engines?.providers[e.rawValue]?.signed_in == true {
            models[e.rawValue] = result
        }
    }

    func setEngine(_ e: Engine, model: String? = nil, effort: String? = nil) async {
        let changed = e != activeEngine
        let modelID = model ?? (changed ? "" : settings.model ?? "")
        var chosenEffort = effort ?? (changed ? Engine.defaultEffort : settings.effort ?? Engine.defaultEffort)
        if chosenEffort != Engine.adaptiveEffort,
           let option = models[e.rawValue]?.models.first(where: { $0.id == modelID }),
           !option.efforts.isEmpty, !option.efforts.contains(chosenEffort) {
            chosenEffort = ["medium", "high"].first(where: option.efforts.contains) ?? option.efforts[0]
        }
        struct Body: Encodable { let provider, model, effort: String }
        let choice = Body(provider: e.rawValue, model: modelID, effort: chosenEffort)
        do {
            settings = try await backend.send("PUT", "/api/settings", choice)
            await loadModels()
        } catch { errorMessage = error.localizedDescription }
    }

    func installEngine(_ e: Engine) async {
        await engineAction("install", for: e)
    }

    func signIn(_ e: Engine) async {
        if activeEngine != e { await setEngine(e) }
        await engineAction("sign-in", for: e)
    }

    func cancelSignIn(_ e: Engine) async {
        await engineAction("cancel-sign-in", for: e)
    }

    func signOut(_ e: Engine) async {
        await engineAction("sign-out", for: e)
    }

    private func engineAction(_ action: String, for e: Engine) async {
        do {
            try await backend.post("/api/engines/\(e.rawValue)/\(action)")
            watchEngines()
        } catch { errorMessage = error.localizedDescription }
    }

    private func watchEngines() {
        enginePoll?.cancel()
        enginePoll = Task { [weak self] in
            for _ in 0..<170 {
                guard let self, !Task.isCancelled else { return }
                await self.loadEngines()
                let busy = self.engines?.providers.values.contains {
                    $0.installing?.state == "running" || $0.sign_in?.state == "running"
                } ?? false
                if !busy { return }
                try? await Task.sleep(for: .seconds(2))
            }
        }
    }

    // MARK: Settings

    func loadSettings() async {
        if let s: SettingsInfo = try? await backend.get("/api/settings") { settings = s }
    }

    func saveSettings() async {
        struct Body: Encodable { let examiner_name, institution: String; let marking_scheme: [String: Int]?; let summary_words: Int?
                                 let grading_scale: GradingScale? }
        let s = settings
        let scheme = s.marking_scheme.flatMap { Scheme.isValid($0) ? $0 : nil }
        let r: SettingsInfo? = try? await backend.send("PUT", "/api/settings",
            Body(examiner_name: s.examiner_name ?? "", institution: s.institution ?? "",
                 marking_scheme: scheme, summary_words: s.summary_words,
                 grading_scale: s.grading_scale.flatMap { $0.isValid ? $0 : nil }))
        if let r {
            // keep in-progress (not yet valid) weight and scale edits on screen
            let editing = settings.marking_scheme, editingScale = settings.grading_scale
            settings = r
            if let editing, !Scheme.isValid(editing) { settings.marking_scheme = editing }
            if let editingScale, !editingScale.isValid { settings.grading_scale = editingScale }
        }
    }
}
