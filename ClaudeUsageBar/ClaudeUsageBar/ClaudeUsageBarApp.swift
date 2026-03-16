import SwiftUI

@main
struct ClaudeUsageBarApp: App {
    @StateObject private var usageModel = UsageModel()
    var body: some Scene {
        MenuBarExtra {
            MenuBarView(model: usageModel)
        } label: {
            UsageMenuBarLabel(model: usageModel)
        }
        .menuBarExtraStyle(.window)
    }
}

/// Manages a standalone NSWindow for settings, since openWindow doesn't work
/// reliably from MenuBarExtra popovers in LSUIElement apps.
class SettingsWindowController {
    static let shared = SettingsWindowController()
    private var window: NSWindow?

    func show(model: UsageModel) {
        if let window = window {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let settingsView = SettingsView(model: model)
        let hostingController = NSHostingController(rootView: settingsView)

        let window = NSWindow(contentViewController: hostingController)
        window.title = "ClaudeUsageBar Settings"
        window.setContentSize(NSSize(width: 380, height: 320))
        window.styleMask = [.titled, .closable]
        window.center()
        window.isReleasedWhenClosed = false
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        self.window = window
    }
}
