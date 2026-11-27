import AppKit
import SwiftUI

/// Developer aid: DE_SNAPSHOT_DIR=/path makes the app capture its own window in each main state, then quit.
enum Snapshot {
    @MainActor
    static func runIfRequested(_ model: AppModel) {
        guard let dir = ProcessInfo.processInfo.environment["DE_SNAPSHOT_DIR"] else { return }
        if ProcessInfo.processInfo.environment["DE_SNAPSHOT_DARK"] != nil { NSApp.appearance = NSAppearance(named: .darkAqua) }
        Task { @MainActor in
            @MainActor func shot(_ name: String) async {
                try? await Task.sleep(for: .seconds(1.5))
                guard let w = NSApp.windows.first(where: { $0.isVisible && $0.title != "" }),
                      let v = w.contentView?.superview ?? w.contentView,
                      let rep = v.bitmapImageRepForCachingDisplay(in: v.bounds) else { return }
                v.cacheDisplay(in: v.bounds, to: rep)
                try? rep.representation(using: .png, properties: [:])?.write(to: URL(fileURLWithPath: dir).appendingPathComponent("\(name).png"))
            }
            try? await Task.sleep(for: .seconds(2))
            await shot("0-welcome")
            if let e = model.exams.first(where: { $0.state == "done" }) {
                await model.select(.exam(e.id)); await shot("2-report")
                model.applySlider(0.5); await shot("3-slider")
                model.dirty = false
            }
            await model.select(.skill); await shot("8-skill")
            let host = NSHostingView(rootView: SettingsView().environment(model))
            let win = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 480, height: 900), styleMask: [.titled], backing: .buffered, defer: false)
            win.contentView = host
            win.setContentSize(host.fittingSize)
            win.orderFront(nil)
            try? await Task.sleep(for: .seconds(2))
            if let rep = host.bitmapImageRepForCachingDisplay(in: host.bounds) {
                host.cacheDisplay(in: host.bounds, to: rep)
                try? rep.representation(using: .png, properties: [:])?.write(to: URL(fileURLWithPath: dir).appendingPathComponent("9-settings.png"))
            }
            win.orderOut(nil)
            // Setup Assistant steps (captured from the sheet window)
            await model.loadEngines()
            for step in 0..<5 {
                model.setupStep = step
                model.showSetup = true
                try? await Task.sleep(for: .seconds(step == 1 ? 6 : 1.5))
                if let sheet = NSApp.windows.compactMap({ $0.attachedSheet }).first ?? NSApp.windows.first(where: { $0.isSheet }),
                   let v = sheet.contentView?.superview ?? sheet.contentView, let rep = v.bitmapImageRepForCachingDisplay(in: v.bounds) {
                    v.cacheDisplay(in: v.bounds, to: rep)
                    try? rep.representation(using: .png, properties: [:])?.write(to: URL(fileURLWithPath: dir).appendingPathComponent("setup-\(step).png"))
                }
            }
            model.showSetup = false
            try? await Task.sleep(for: .seconds(1))
            // Simulated running examination
            let fake = #"{"id":"fake","state":"running","pdf":"Example.pdf","student":"","title":"","status":{"state":"running","original_name":"Example Thesis.pdf","run_kind":"examine","level":"phd","started":"2026-11-25T13:00:00"},"proposed":{},"page_labels":[]}"#
            let prog = #"{"next":0,"state":"running","run_kind":"examine","started":"2026-11-25T13:00:00","fraction":0.44,"phases":[{"key":"extract","label":"Extract text and page numbers","state":"done"},{"key":"map","label":"Map structure, aims and objectives","state":"done"},{"key":"read","label":"Three examiners read the dissertation","state":"done"},{"key":"chair","label":"Chair settles disputed criteria","state":"current"},{"key":"marks","label":"Decide marks and apply calibration","state":"pending"},{"key":"report","label":"Write the report","state":"pending"},{"key":"verify","label":"Verify page references and checks","state":"pending"}]}"#
            model.selection = .exam("fake")
            model.detail = try? JSONDecoder().decode(ExamDetail.self, from: Data(fake.utf8))
            model.progress = try? JSONDecoder().decode(ProgressInfo.self, from: Data(prog.utf8))
            await shot("7-running")
            NSApp.terminate(nil)
        }
    }
}
