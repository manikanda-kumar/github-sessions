import SwiftUI

@main
struct GitHubSessionsApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var store = GitRepoStore()
    @AppStorage(AppPreferences.menuBarEnabledKey) private var menuBarEnabled = true

    var body: some Scene {
        WindowGroup("GitHub Sessions") {
            ContentView()
                .environmentObject(store)
                .onAppear {
                    appDelegate.configure(store: store, menuBarEnabled: menuBarEnabled)
                }
                .onChange(of: menuBarEnabled) { _, enabled in
                    appDelegate.menuBarController?.setEnabled(enabled)
                }
        }
        .defaultSize(width: 860, height: 620)

        Settings {
            SettingsView()
                .environmentObject(store)
        }
    }
}