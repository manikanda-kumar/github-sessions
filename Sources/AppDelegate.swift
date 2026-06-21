import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    var menuBarController: MenuBarController?
    private var didConfigure = false

    func configure(store: GitRepoStore, menuBarEnabled: Bool) {
        guard !didConfigure else {
            menuBarController?.setEnabled(menuBarEnabled)
            return
        }
        didConfigure = true
        applyActivationPolicy()
        let controller = MenuBarController(store: store)
        menuBarController = controller
        controller.setEnabled(menuBarEnabled)
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        applyActivationPolicy()
        applyApplicationIcon()
    }

    private func applyApplicationIcon() {
        guard NSApp.applicationIconImage == nil else { return }
        if let icon = NSImage(named: "MenuBarIcon") {
            let sized = NSImage(size: NSSize(width: 512, height: 512))
            sized.lockFocus()
            icon.draw(in: NSRect(x: 0, y: 0, width: 512, height: 512))
            sized.unlockFocus()
            NSApp.applicationIconImage = sized
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            AppWindowRouter.showMainWindow()
        }
        return true
    }

    private func applyActivationPolicy() {
        let hideDock = UserDefaults.standard.object(forKey: AppPreferences.hideDockIconKey) as? Bool ?? false
        NSApp.setActivationPolicy(hideDock ? .accessory : .regular)
    }
}

enum AppPreferences {
    static let menuBarEnabledKey = "MenuBarEnabled"
    static let hideDockIconKey = "HideDockIcon"
}