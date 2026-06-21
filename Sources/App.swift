import SwiftUI

@main
struct GitHubSessionsApp: App {
    @StateObject private var store = GitRepoStore()

    var body: some Scene {
        WindowGroup("GitHub Sessions") {
            ContentView()
                .environmentObject(store)
        }
        .defaultSize(width: 860, height: 620)

        Settings {
            SettingsView()
                .environmentObject(store)
        }
    }
}