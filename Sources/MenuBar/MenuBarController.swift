import AppKit
import SwiftUI
import Combine

@MainActor
final class MenuBarController: NSObject {
    private let store: GitRepoStore
    private var statusItem: NSStatusItem?
    private var hostingView: NSHostingView<MenuBarLabelView>?
    private var cancellables: Set<AnyCancellable> = []

    init(store: GitRepoStore) {
        self.store = store
        super.init()
    }

    func setEnabled(_ enabled: Bool) {
        if enabled {
            ensureStatusItem()
        } else {
            removeStatusItem()
        }
    }

    private func ensureStatusItem() {
        guard statusItem == nil else {
            refreshLabel(pendingCount: store.repos.count, isScanning: store.isScanning)
            return
        }

        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem = item

        guard let button = item.button else { return }
        button.title = ""
        button.image = nil
        button.target = self
        button.action = #selector(showMenu(_:))
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])

        let label = MenuBarLabelView(pendingCount: store.repos.count, isScanning: store.isScanning)
        let host = NSHostingView(rootView: label)
        host.translatesAutoresizingMaskIntoConstraints = false
        button.addSubview(host)
        NSLayoutConstraint.activate([
            host.leadingAnchor.constraint(equalTo: button.leadingAnchor),
            host.trailingAnchor.constraint(equalTo: button.trailingAnchor),
            host.topAnchor.constraint(equalTo: button.topAnchor),
            host.bottomAnchor.constraint(equalTo: button.bottomAnchor),
        ])
        hostingView = host
        updateLength()

        cancellables.removeAll()
        Publishers.CombineLatest(store.$repos, store.$isScanning)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] repos, isScanning in
                self?.refreshLabel(pendingCount: repos.count, isScanning: isScanning)
            }
            .store(in: &cancellables)

        refreshLabel(pendingCount: store.repos.count, isScanning: store.isScanning)
    }

    private func removeStatusItem() {
        if let item = statusItem {
            NSStatusBar.system.removeStatusItem(item)
        }
        statusItem = nil
        hostingView = nil
        cancellables.removeAll()
    }

    private func refreshLabel(pendingCount: Int, isScanning: Bool) {
        hostingView?.rootView = MenuBarLabelView(
            pendingCount: pendingCount,
            isScanning: isScanning
        )
        updateLength()
    }

    private func updateLength() {
        guard let item = statusItem, let host = hostingView else { return }
        let size = host.fittingSize
        item.length = max(28, size.width + 8)
    }

    @objc private func showMenu(_ sender: NSStatusBarButton) {
        guard let item = statusItem else { return }
        let menu = buildMenu()
        item.menu = menu
        sender.performClick(nil)
        item.menu = nil
    }

    private func buildMenu() -> NSMenu {
        let menu = NSMenu()
        let count = store.repos.count

        let title = NSMenuItem(title: count == 0 ? "All caught up" : "\(count) repo\(count == 1 ? "" : "s") pending", action: nil, keyEquivalent: "")
        title.isEnabled = false
        menu.addItem(title)

        if let lastScanAt = store.lastScanAt {
            let formatter = RelativeDateTimeFormatter()
            formatter.unitsStyle = .abbreviated
            let relative = formatter.localizedString(for: lastScanAt, relativeTo: .now)
            let subtitle = NSMenuItem(title: "Updated \(relative)", action: nil, keyEquivalent: "")
            subtitle.isEnabled = false
            menu.addItem(subtitle)
        }

        if !store.repos.isEmpty {
            menu.addItem(.separator())
            for repo in store.repos.prefix(12) {
                let item = NSMenuItem(
                    title: "\(repo.name) · \(repo.lastActivityLabel) — \(repo.summary)",
                    action: #selector(openRepoInITerm(_:)),
                    keyEquivalent: ""
                )
                item.target = self
                item.representedObject = repo.path
                menu.addItem(item)
            }
            if store.repos.count > 12 {
                let more = NSMenuItem(
                    title: "… and \(store.repos.count - 12) more",
                    action: #selector(openMainWindow),
                    keyEquivalent: ""
                )
                more.target = self
                menu.addItem(more)
            }
        }

        menu.addItem(.separator())

        let openTitle = AppWindowRouter.isMainWindowVisible ? "Hide GitHub Sessions" : "Open GitHub Sessions"
        menu.addItem(
            NSMenuItem(title: openTitle, action: #selector(toggleMainWindow), keyEquivalent: "o")
        )

        let refresh = NSMenuItem(title: store.isScanning ? "Scanning…" : "Refresh", action: #selector(refresh), keyEquivalent: "r")
        refresh.isEnabled = !store.isScanning
        menu.addItem(refresh)

        menu.addItem(
            NSMenuItem(title: "Settings…", action: #selector(openSettings), keyEquivalent: ",")
        )
        menu.addItem(.separator())
        menu.addItem(
            NSMenuItem(title: "Quit GitHub Sessions", action: #selector(quit), keyEquivalent: "q")
        )

        for item in menu.items where item.action != nil {
            item.target = self
        }

        return menu
    }

    @objc private func openMainWindow() {
        AppWindowRouter.showMainWindow()
    }

    @objc private func toggleMainWindow() {
        if AppWindowRouter.isMainWindowVisible,
           let window = NSApp.windows.first(where: { $0.title == "GitHub Sessions" }) {
            window.orderOut(nil)
        } else {
            AppWindowRouter.showMainWindow()
        }
    }

    @objc private func refresh() {
        Task { await store.refresh(force: true) }
    }

    @objc private func openSettings() {
        AppWindowRouter.showSettings()
    }

    @objc private func openRepoInITerm(_ sender: NSMenuItem) {
        guard let url = sender.representedObject as? URL else { return }
        ITermLauncher.openGitStatus(at: url)
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}