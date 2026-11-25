import AppKit
import PDFKit
import SwiftUI

struct ContentView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model
        NavigationSplitView {
            SidebarView()
                .navigationSplitViewColumnWidth(min: 230, ideal: 270, max: 360)
        } detail: {
            DetailView()
                .inspector(isPresented: $model.showPDF) {
                    PDFInspector()
                        .inspectorColumnWidth(min: 360, ideal: 520, max: 900)
                }
        }
        .dropDestination(for: URL.self) { urls, _ in
            let pdfs = urls.filter { $0.pathExtension.lowercased() == "pdf" }
            Task { for u in pdfs { await model.importPDF(u) } }
            return !pdfs.isEmpty
        }
        .alert("Save changes to the examiner's report?", isPresented: $model.showDiscardAlert) {
            Button("Save") { Task { await model.confirmDiscard(save: true) } }
            Button("Don't Save", role: .destructive) { Task { await model.confirmDiscard(save: false) } }
            Button("Cancel", role: .cancel) { model.pendingSelection = nil }
        } message: {
            Text("Your changes will be lost if you don't save them.")
        }
        .alert("Something went wrong", isPresented: Binding(get: { model.errorMessage != nil }, set: { if !$0 { model.errorMessage = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(model.errorMessage ?? "")
        }
        .confirmationDialog("Move “\(model.deleteTargetName)” to the Trash?", isPresented: $model.showDeleteConfirm) {
            Button("Move to Trash", role: .destructive) { Task { await model.deleteSelected() } }
        } message: {
            Text("Its PDF, report and working notes are moved to the Trash, and it is removed from your calibration. You can restore the files from the Trash.")
        }
        .sheet(isPresented: $model.showRevise) { ReviseSheet() }
        .sheet(isPresented: $model.showSetup) { SetupView().environment(model) }
    }
}

// MARK: - Sidebar

struct SidebarView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let selection = Binding<SidebarItem?>(get: { model.selection }, set: { model.requestSelection($0) })
        List(selection: selection) {
            Section {
                Label("Examining Standards", systemImage: "text.book.closed")
                    .tag(SidebarItem.skill)
                Label("Calibration", systemImage: "dial.medium")
                    .tag(SidebarItem.calibration)
            }
            Section("Examinations") {
                ForEach(model.filteredExams) { exam in
                    ExamRow(exam: exam)
                        .tag(SidebarItem.exam(exam.id))
                        .contextMenu {
                            Button("Show in Finder") {
                                NSWorkspace.shared.activateFileViewerSelecting([model.backend.examsDir.appendingPathComponent(exam.id)])
                            }
                            Divider()
                            Button("Move to Trash…", role: .destructive) { model.confirmDelete(exam.id) }
                                .disabled(exam.state == "running")
                        }
                }
            }
        }
        .listStyle(.sidebar)
        .onDeleteCommand { model.confirmDelete() }
        .searchable(text: Binding(get: { model.search }, set: { model.search = $0 }), placement: .sidebar, prompt: "Search")
        .safeAreaInset(edge: .bottom, spacing: 0) {
            VStack(spacing: 0) { Divider(); EngineStatusBar() }.background(.bar)
        }
        .overlay {
            if model.engineReady && model.exams.isEmpty {
                ContentUnavailableView {
                    Label("No Examinations", systemImage: "doc.text.magnifyingglass")
                } description: {
                    Text("Drag a dissertation PDF here, or click the Add button.")
                }
            }
        }
        .toolbar {
            ToolbarItem {
                Button { model.chooseAndImport() } label: { Label("New Examination", systemImage: "plus") }
                    .help("Add a dissertation PDF to examine (⌘N)")
                    .disabled(!model.engineReady)
            }
        }
    }
}

struct ExamRow: View {
    let exam: ExamSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(exam.displayName).font(.headline).lineLimit(1)
            if !exam.title.isEmpty {
                Text(exam.title).font(.subheadline).foregroundStyle(.secondary).lineLimit(2)
            }
            HStack(spacing: 6) {
                StatusBadge(state: exam.state)
                if let l = exam.level, let lv = Level(rawValue: l), exam.state != "new" {
                    LevelCapsule(level: lv)
                }
                Spacer()
                if let t = exam.total {
                    Text(exam.viva.map { "\(Fmt.mark(t + $0))/100" } ?? "\(Fmt.mark(t))/\(exam.dissertation_max ?? 90)")
                        .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 3)
    }
}

struct StatusBadge: View {
    let state: String

    var body: some View {
        let (text, color, icon): (String, Color, String) = switch state {
        case "running": ("Examining", .accentColor, "hourglass")
        case "done": ("Ready", .green, "checkmark.circle.fill")
        case "error", "interrupted", "cancelled": ("Needs attention", .orange, "exclamationmark.triangle.fill")
        default: ("Not started", .secondary, "circle.dashed")
        }
        HStack(spacing: 4) {
            if state == "running" {
                ProgressView().controlSize(.mini)
            } else {
                Image(systemName: icon)
            }
            Text(text)
        }
        .font(.caption)
        .foregroundStyle(color)
    }
}

// MARK: - Detail router

struct DetailView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        Group {
            if let err = model.engineError {
                ContentUnavailableView {
                    Label("The Examination Engine Could Not Start", systemImage: "exclamationmark.triangle")
                } description: {
                    Text(err)
                }
            } else if !model.engineReady {
                ProgressView("Starting…")
            } else {
                switch model.selection {
                case .calibration:
                    CalibrationView()
                case .skill:
                    SkillView()
                case .exam:
                    if let d = model.detail {
                        ExamView(detail: d)
                    } else {
                        ProgressView()
                    }
                case nil:
                    WelcomeView()
                }
            }
        }
    }
}

struct ExamView: View {
    @Environment(AppModel.self) private var model
    let detail: ExamDetail

    var body: some View {
        Group {
            if detail.state == "running" {
                RunningView(detail: detail)
            } else if model.draft == nil {
                StartView(detail: detail)
            } else {
                ReportEditor()
            }
        }
        .navigationTitle(model.draft?.student.isEmpty == false ? model.draft!.student : (detail.status.original_name ?? detail.pdf))
        .navigationSubtitle(model.draft?.title ?? "")
        .toolbar { ExamToolbar(detail: detail) }
    }
}

struct ExamToolbar: ToolbarContent {
    @Environment(AppModel.self) private var model
    let detail: ExamDetail

    var body: some ToolbarContent {
        ToolbarItemGroup(placement: .primaryAction) {
            if model.draft != nil && detail.state != "running" {
                Button { model.showRevise = true } label: { Label("Revise Report", systemImage: "pencil.line") }
                    .help("Describe a change to the report (⇧⌘R)")
                Button { model.exportWord() } label: {
                    Label("Export Report", systemImage: "square.and.arrow.up")
                }
                .help("Save the report as a Word document (⇧⌘E)")
                .disabled(model.reportDocxURL == nil)
                Button { Task { await model.save() } } label: {
                    if model.isSaving { ProgressView().controlSize(.small) } else { Label("Save", systemImage: "checkmark") }
                }
                .help("Save the report and update the Word document (⌘S)")
                .disabled(!model.canSave)
            }
            if detail.state != "running" {
                Button(role: .destructive) { model.confirmDelete() } label: { Label("Move to Trash", systemImage: "trash") }
                    .help("Move this examination to the Trash (⌘⌫)")
            }
            Button { model.showPDF.toggle() } label: { Label("Dissertation PDF", systemImage: "sidebar.trailing") }
                .help("Show or hide the dissertation (⌥⌘P)")
        }
    }
}

// MARK: - Not started / error

struct StartView: View {
    @Environment(AppModel.self) private var model
    let detail: ExamDetail

    var body: some View {
        @Bindable var model = model
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
                Text("Laurea reads the whole dissertation, checks it against the current literature and the marking criteria, screens references and originality, and drafts the examiner's report for you to review.")
                    .multilineTextAlignment(.center).foregroundStyle(.secondary).frame(maxWidth: 460)
            }
            Picker("Level", selection: $model.newLevel) {
                ForEach(Level.allCases) { Text($0.label).tag($0) }
            }
            .pickerStyle(.segmented)
            .frame(width: 240)
            .help("BSc, MSc or PhD: the expected standard and your calibration depend on the level")
            Button { Task { await model.examine() } } label: {
                Text(detail.state == "new" ? "Examine \(model.newLevel.noun)" : "Run Again").frame(minWidth: 180)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .keyboardShortcut(.defaultAction)
            let sc = detail.markingScheme
            HStack(spacing: 4) {
                Text("Marked out of \(sc.dissertationMax), viva out of \(sc.viva) · usually 20–60 minutes ·")
                SettingsLink { Text("Change weights…") }.buttonStyle(.link)
            }
            .font(.caption).foregroundStyle(.tertiary)
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Running

struct RunningView: View {
    @Environment(AppModel.self) private var model
    let detail: ExamDetail

    var body: some View {
        let p = model.progress
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .center, spacing: 14) {
                Image(systemName: detail.status.run_kind == "revise" ? "pencil.line" : "text.magnifyingglass")
                    .font(.system(size: 30, weight: .medium))
                    .foregroundStyle(.tint)
                    .symbolEffect(.pulse, options: .repeating)
                    .frame(width: 52, height: 52)
                    .background(Color.accentColor.opacity(0.12), in: .rect(cornerRadius: 12))
                VStack(alignment: .leading, spacing: 4) {
                    Text(detail.status.run_kind == "revise" ? "Revising the Report" : "Examining the \(Level(rawValue: detail.status.level ?? "msc")?.noun ?? "Dissertation")")
                        .font(.title2.weight(.semibold))
                    Text(detail.status.original_name ?? detail.pdf).foregroundStyle(.secondary)
                }
                Spacer()
                Button("Stop", role: .destructive) { Task { await model.stopRun() } }
            }
            if detail.status.run_kind == "revise" {
                ProgressView().progressViewStyle(.linear)
                Text("Applying your request…").foregroundStyle(.secondary)
            } else {
                ProgressView(value: p?.fraction ?? 0.02)
                    .progressViewStyle(.linear)
                    .animation(.easeInOut, value: p?.fraction)
                HStack {
                    Text((p?.phases.first { $0.state == "current" }?.label).map { "\($0)…" } ?? "Starting…")
                    Spacer()
                    ElapsedText(start: p?.started ?? detail.status.started)
                }
                .font(.callout).foregroundStyle(.secondary)
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(p?.phases ?? []) { ph in
                        HStack(spacing: 10) {
                            Group {
                                if ph.state == "current" {
                                    ProgressView().controlSize(.small)
                                } else {
                                    Image(systemName: ph.state == "done" ? "checkmark.circle.fill" : "circle")
                                        .foregroundStyle(ph.state == "done" ? Color.green : Color.secondary.opacity(0.5))
                                        .contentTransition(.symbolEffect(.replace))
                                }
                            }
                            .frame(width: 18)
                            .animation(.default, value: ph.state)
                            Text(ph.label)
                                .fontWeight(ph.state == "current" ? .semibold : .regular)
                                .foregroundStyle(ph.state == "pending" ? .secondary : .primary)
                        }
                    }
                }
                .padding(.top, 4)
            }
            Text("You can keep working in other examinations while this runs. You'll be notified when the report is ready.")
                .font(.caption).foregroundStyle(.tertiary)
        }
        .padding(28)
        .frame(maxWidth: 580)
        .background(.regularMaterial, in: .rect(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(.separator.opacity(0.5)))
        .shadow(color: .black.opacity(0.08), radius: 20, y: 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct ElapsedText: View {
    let start: String?

    var body: some View {
        TimelineView(.periodic(from: .now, by: 30)) { ctx in
            Text(label(now: ctx.date)).monospacedDigit()
        }
    }

    func label(now: Date) -> String {
        guard let start, let d = ISO8601DateFormatter.local.date(from: start) else { return "" }
        let m = max(0, Int(now.timeIntervalSince(d) / 60))
        return m < 1 ? "Just started" : "\(m) min"
    }
}

extension ISO8601DateFormatter {
    static let local: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withFullDate, .withTime, .withColonSeparatorInTime, .withDashSeparatorInDate]
        f.timeZone = .current
        return f
    }()
}

// MARK: - Revise sheet

struct ReviseSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        @Bindable var model = model
        VStack(alignment: .leading, spacing: 12) {
            Text("Revise the Report").font(.headline)
            Text("Describe the change. The report is revised, its page references are re-checked and the Word document is updated.")
                .font(.callout).foregroundStyle(.secondary)
            TextEditor(text: $model.reviseText)
                .font(.body)
                .frame(minHeight: 120)
                .scrollContentBackground(.hidden)
                .padding(6)
                .background(.background, in: .rect(cornerRadius: 6))
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(.separator))
            if model.dirty {
                Label("Save your own edits first, or they will be overwritten.", systemImage: "exclamationmark.triangle.fill")
                    .font(.caption).foregroundStyle(.orange)
            }
            HStack {
                Spacer()
                Button("Cancel", role: .cancel) { dismiss() }.keyboardShortcut(.cancelAction)
                Button("Revise") { dismiss(); Task { await model.revise() } }
                    .keyboardShortcut(.defaultAction)
                    .disabled(model.reviseText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || model.dirty)
            }
        }
        .padding(20)
        .frame(width: 520)
    }
}

// MARK: - PDF inspector

struct PDFInspector: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(spacing: 0) {
            if let url = model.pdfURL {
                PDFKitView(url: url, labels: model.detail?.page_labels ?? [], target: model.pdfTarget, currentLabel: Binding(get: { model.pdfCurrentLabel }, set: { model.pdfCurrentLabel = $0 }))
                HStack {
                    Text(model.pdfCurrentLabel.isEmpty ? "" : "Page \(model.pdfCurrentLabel)").font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    Button("Open in Preview") { NSWorkspace.shared.open(url) }.buttonStyle(.link).font(.caption)
                }
                .padding(.horizontal, 10).padding(.vertical, 6)
            } else {
                ContentUnavailableView("No PDF", systemImage: "doc")
            }
        }
    }
}

struct PDFKitView: NSViewRepresentable {
    let url: URL
    let labels: [String]
    let target: PDFTarget?
    @Binding var currentLabel: String

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> PDFView {
        let v = PDFView()
        v.autoScales = true
        v.displayMode = .singlePageContinuous
        v.backgroundColor = .windowBackgroundColor
        v.document = PDFDocument(url: url)
        context.coordinator.observe(v)
        return v
    }

    func updateNSView(_ v: PDFView, context: Context) {
        context.coordinator.parent = self
        if v.document?.documentURL != url { v.document = PDFDocument(url: url) }
        if let t = target, t.token != context.coordinator.lastToken {
            context.coordinator.lastToken = t.token
            go(v, to: t.label)
        }
    }

    private func go(_ v: PDFView, to label: String) {
        guard let doc = v.document else { return }
        let lower = labels.map { $0.lowercased() }
        var index = lower.firstIndex(of: label.lowercased())
        if index == nil {
            for i in 0..<doc.pageCount where doc.page(at: i)?.label?.lowercased() == label.lowercased() { index = i; break }
        }
        if index == nil, let n = Int(label) { index = n - 1 }
        if let i = index, let page = doc.page(at: max(0, min(doc.pageCount - 1, i))) { v.go(to: page) }
    }

    final class Coordinator: NSObject {
        var parent: PDFKitView
        var lastToken: UUID?
        init(_ p: PDFKitView) { parent = p }

        func observe(_ v: PDFView) {
            NotificationCenter.default.addObserver(forName: .PDFViewPageChanged, object: v, queue: .main) { [weak self, weak v] _ in
                guard let self, let page = v?.currentPage, let doc = v?.document else { return }
                let i = doc.index(for: page)
                let lab = i < self.parent.labels.count && !self.parent.labels[i].isEmpty ? self.parent.labels[i] : (page.label ?? "\(i + 1)")
                self.parent.currentLabel = lab
            }
        }
    }
}
