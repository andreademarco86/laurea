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
            }
            CommandGroup(replacing: .saveItem) {
                Button("Save") { Task { await model.save() } }
                    .keyboardShortcut("s")
                    .disabled(!model.canSave)
                Button("Export Report…") { Task { await model.exportWord() } }
                    .keyboardShortcut("e", modifiers: [.command, .shift])
                    .disabled(model.draft == nil || model.detail?.state == "running")  // export explains what's missing
            }
            CommandMenu("Examination") {
                Button("Examine Dissertation") { Task { await model.examine() } }
                    .keyboardShortcut("r")
                    .disabled(model.detail == nil || model.detail?.state == "running" || model.draft != nil)
                Button("Revise Report…") { model.showRevise = true }
                    .keyboardShortcut("r", modifiers: [.command, .shift])
                    .disabled(model.draft == nil || model.detail?.state == "running")
                Divider()
                Button(model.showPDF ? "Hide Dissertation PDF" : "Show Dissertation PDF") { model.showPDF.toggle() }
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
            a.messageText = "Save changes to the examiner's report?"
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
            a.messageText = "An examination is still in progress."
            a.informativeText = "Quitting stops the examination. You can run it again later."
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
