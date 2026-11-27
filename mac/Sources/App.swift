import AppKit
import SwiftUI
import UserNotifications

@main
struct LaureaApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    private let model = AppModel.shared

    var body: some Scene {
        Window("Laurea", id: "main") {
            ContentView()
                .environment(model)
                .frame(minWidth: 940, minHeight: 620)
                .task { await model.boot() }
        }
        .defaultSize(width: 1280, height: 860)
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("About Laurea") { SystemIntegration.showAbout() }
                Button("Setup Assistant…") { model.openSetup() }
                    .disabled(!model.engineReady)
            }
            CommandGroup(replacing: .newItem) {
                Button("New Examination…") { model.chooseAndImport() }
                    .keyboardShortcut("n")
                    .disabled(!model.engineReady)
                Button("New Paper Review…") { model.chooseAndImport(review: true) }
                    .keyboardShortcut("n", modifiers: [.command, .shift])
                    .disabled(!model.engineReady)
            }
            CommandGroup(replacing: .saveItem) {
                Button("Save") { Task { await model.save() } }
                    .keyboardShortcut("s")
                    .disabled(!model.canSave)
                Button(model.isReview ? "Export Review…" : "Export Report…") { Task { await model.exportWord() } }
                    .keyboardShortcut("e", modifiers: [.command, .shift])
                    .disabled(!model.hasDraft || model.detail?.state == "running")  // export explains what's missing
                if model.isReview {
                    Button("Copy Review for Submission") { Task { await model.copyReviewForm() } }
                        .keyboardShortcut("c", modifiers: [.command, .shift])
                        .disabled(!model.hasDraft || model.detail?.state == "running")
                }
            }
            CommandMenu("Examination") {
                Button(model.isReview ? "Review Paper" : "Examine Dissertation") { Task { await model.examine() } }
                    .keyboardShortcut("r")
                    .disabled(model.detail == nil || model.detail?.state == "running" || model.hasDraft)
                Button(model.isReview ? "Revise Review…" : "Revise Report…") { model.showRevise = true }
                    .keyboardShortcut("r", modifiers: [.command, .shift])
                    .disabled(!model.hasDraft || model.detail?.state == "running")
                Divider()
                Button(model.showPDF ? "Hide PDF" : "Show PDF") { model.showPDF.toggle() }
                    .keyboardShortcut("p", modifiers: [.command, .option])
                    .disabled(model.detail == nil)
                Button("Show in Finder") { model.revealInFinder() }
                    .disabled(model.detail == nil)
                Divider()
                Button("Examining Standards") { model.requestSelection(.skill) }
                    .keyboardShortcut("l", modifiers: [.command, .shift])
                Button("Calibration") { model.requestSelection(.calibration) }
                    .keyboardShortcut("k", modifiers: [.command, .shift])
                Button("Open Calibration Notes") { model.openCalibrationNotes() }
                Divider()
                Button("Move to Trash…") { model.confirmDelete() }
                    .keyboardShortcut(.delete, modifiers: [.command])
                    .disabled(model.detail == nil || model.detail?.state == "running")
            }
            SidebarCommands()
            InspectorCommands()
        }

        Settings {
            SettingsView()
                .environment(model)
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }

    func applicationDidFinishLaunching(_ notification: Notification) {
        UNUserNotificationCenter.current().delegate = self
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }

    @MainActor
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard let model = AppModel.current else { return .terminateNow }
        if model.dirty {
            let a = NSAlert()
            a.messageText = model.isReview ? "Save changes to the review?" : "Save changes to the examiner's report?"
            a.informativeText = "Your changes will be lost if you don't save them."
            a.addButton(withTitle: "Save")
            a.addButton(withTitle: "Cancel")
            a.addButton(withTitle: "Don't Save")
            switch a.runModal() {
            case .alertFirstButtonReturn:
                Task { @MainActor in
                    await model.save()
                    if !model.dirty { NSApp.reply(toApplicationShouldTerminate: true) } else { NSApp.reply(toApplicationShouldTerminate: false) }
                }
                return .terminateLater
            case .alertSecondButtonReturn:
                return .terminateCancel
            default:
                break
            }
        }
        if model.anyRunning {
            let a = NSAlert()
            a.alertStyle = .warning
            a.messageText = "An examination or review is still in progress."
            a.informativeText = "Quitting stops it. You can run it again later."
            a.addButton(withTitle: "Cancel")
            a.addButton(withTitle: "Quit Anyway")
            if a.runModal() == .alertFirstButtonReturn { return .terminateCancel }
        }
        return .terminateNow
    }

    func applicationWillTerminate(_ notification: Notification) {
        Backend.shared.stop()
    }
}
