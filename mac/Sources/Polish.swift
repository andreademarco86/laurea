import AppKit
import SwiftUI
import UserNotifications

// MARK: - Welcome

struct WelcomeView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        ScrollView {
            VStack(spacing: 30) {
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .frame(width: 128, height: 128)
                    .shadow(color: .black.opacity(0.18), radius: 12, y: 6)
                VStack(spacing: 8) {
                    Text("Welcome to Laurea")
                        .font(.system(size: 34, weight: .bold))
                    Text("Fair, thorough examiner's reports, drafted by Claude and finished by you.")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                VStack(alignment: .leading, spacing: 20) {
                    FeatureRow(icon: "doc.text.magnifyingglass", tint: .blue, title: "Reads every page",
                               text: "Figures, tables and results included, judged against ML, computer vision, astronomy and computational physics standards.")
                    FeatureRow(icon: "books.vertical.fill", tint: .orange, title: "Knows the field",
                               text: "Searches the current literature, verifies references and screens for originality.")
                    FeatureRow(icon: "dial.medium.fill", tint: .green, title: "Learns your standard",
                               text: "Adjust the marks once and Laurea calibrates the next report to you, for BSc, MSc and PhD.")
                    FeatureRow(icon: "signature", tint: .purple, title: "Ready to sign",
                               text: "Viva questions, corrections and your signature, exported to Word.")
                }
                .frame(maxWidth: 460)
                VStack(spacing: 10) {
                    Button { model.chooseAndImport() } label: {
                        Text("Add Dissertation…").frame(minWidth: 200)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .keyboardShortcut(.defaultAction)
                    .disabled(!model.engineReady)
                    Text("or drop PDFs anywhere in this window")
                        .font(.callout).foregroundStyle(.tertiary)
                }
            }
            .padding(48)
            .frame(maxWidth: .infinity, minHeight: 560)
        }
    }
}

struct FeatureRow: View {
    let icon: String
    let tint: Color
    let title: String
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 26))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(tint.gradient)
                .frame(width: 40)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                Text(text).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

// MARK: - Score header

struct MarkRing: View {
    let value: Double?
    let max: Double
    let caption: String
    var colors: [Color] = [.blue, .indigo, .purple]
    var size: CGFloat = 92

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .stroke(.quaternary, style: StrokeStyle(lineWidth: 9, dash: value == nil ? [3, 5] : []))
                Circle()
                    .trim(from: 0, to: CGFloat(min(1, (value ?? 0) / max)))
                    .stroke(AngularGradient(colors: colors + [colors.first!], center: .center),
                            style: StrokeStyle(lineWidth: 9, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                VStack(spacing: 0) {
                    Text(value.map { Fmt.mark($0) } ?? "–")
                        .font(.system(size: size * 0.3, weight: .bold, design: .rounded))
                        .contentTransition(.numericText(value: value ?? 0))
                        .monospacedDigit()
                    Text("/ \(Int(max))").font(.caption).foregroundStyle(.secondary)
                }
            }
            .frame(width: size, height: size)
            .animation(.spring(duration: 0.5), value: value)
            Text(caption).font(.caption.weight(.medium)).foregroundStyle(.secondary)
        }
    }
}

struct ScoreHeader: View {
    @Environment(AppModel.self) private var model
    let draft: ReportDraft

    var body: some View {
        let level = Level(rawValue: model.detail?.status.level ?? "msc") ?? .msc
        HStack(spacing: 26) {
            MarkRing(value: Double(draft.total), max: Double(draft.dissertationMax), caption: "Dissertation")
            MarkRing(value: draft.viva.map { Double(draft.total) + $0 }, max: 100, caption: "Final",
                     colors: [.green, .mint, .teal])
            VStack(alignment: .leading, spacing: 8) {
                Text(draft.student.isEmpty ? "Student" : draft.student)
                    .font(.title2.weight(.semibold))
                Text(draft.title)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
                HStack(spacing: 8) {
                    LevelCapsule(level: level)
                    if let pt = model.proposedTotal {
                        Pill(text: "Claude proposed \(pt)", icon: "sparkles", tint: .secondary)
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
        .padding(.vertical, 10)
    }
}

struct LevelCapsule: View {
    let level: Level
    var color: Color { [.bsc: Color.teal, .msc: Color.indigo, .phd: Color.purple][level]! }
    var body: some View {
        Text(level.label)
            .font(.caption2.weight(.bold))
            .padding(.horizontal, 7).padding(.vertical, 2)
            .foregroundStyle(color)
            .background(color.opacity(0.15), in: .capsule)
    }
}

struct Pill: View {
    let text: String
    let icon: String
    let tint: Color
    var body: some View {
        Label(text, systemImage: icon)
            .font(.caption)
            .foregroundStyle(tint)
            .padding(.horizontal, 8).padding(.vertical, 3)
            .background(.quaternary.opacity(0.5), in: .capsule)
    }
}

// MARK: - Sidebar status bar

struct EngineStatusBar: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let running = model.exams.filter { $0.state == "running" }.count
        HStack(spacing: 8) {
            if running > 0 {
                ProgressView().controlSize(.mini)
                Text("Examining \(running) dissertation\(running == 1 ? "" : "s")…")
            } else {
                Circle()
                    .fill(model.engineError != nil ? Color.red : model.engineReady ? Color.green : Color.orange)
                    .frame(width: 7, height: 7)
                Text(model.engineError != nil ? "Engine stopped" : model.engineReady ? "Claude Opus 5.5 · Ready" : "Starting…")
            }
            Spacer()
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
    }
}

// MARK: - Notifications, Dock badge, About

enum SystemIntegration {
    static func requestNotifications() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }

    static func notifyReady(_ exam: ExamSummary) {
        let c = UNMutableNotificationContent()
        c.title = exam.state == "done" ? "Report ready" : "Examination needs attention"
        var body = exam.displayName
        if let t = exam.total, exam.state == "done" { body += " · \(Fmt.mark(t)) / \(exam.dissertation_max ?? 90)" }
        c.body = body
        c.sound = .default
        UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: exam.id + "-" + exam.state, content: c, trigger: nil))
        NSApp.requestUserAttention(.informationalRequest)
    }

    @MainActor
    static func updateDockBadge(running: Int) {
        NSApp.dockTile.badgeLabel = running > 0 ? String(running) : nil
    }

    @MainActor
    static func showAbout() {
        let credits = NSMutableAttributedString(
            string: "Fair, thorough examiner's reports for BSc, MSc and PhD dissertations in ML, AI and computational physics.\n\nDrafted by Claude Opus 5.5 with the dissertation-examiner skill. Finished, calibrated and signed by you.",
            attributes: [.font: NSFont.systemFont(ofSize: 11), .foregroundColor: NSColor.secondaryLabelColor])
        let p = NSMutableParagraphStyle(); p.alignment = .center
        credits.addAttribute(.paragraphStyle, value: p, range: NSRange(location: 0, length: credits.length))
        NSApp.orderFrontStandardAboutPanel(options: [.applicationName: "Laurea", .credits: credits])
        NSApp.activate(ignoringOtherApps: true)
    }
}
