import AppKit

@MainActor
enum AppWindowRouter {
    private static let windowTitle = "GitHub Sessions"

    static func showMainWindow() {
        NSApp.activate(ignoringOtherApps: true)
        if let window = existingMainWindow() {
            window.makeKeyAndOrderFront(nil)
            return
        }
        NSApp.windows.forEach { window in
            if window.canBecomeMain {
                window.makeKeyAndOrderFront(nil)
            }
        }
    }

    static func showSettings() {
        NSApp.activate(ignoringOtherApps: true)
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
    }

    static var isMainWindowVisible: Bool {
        existingMainWindow()?.isVisible ?? false
    }

    private static func existingMainWindow() -> NSWindow? {
        NSApp.windows.first { $0.title == windowTitle }
    }
}