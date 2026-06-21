import SwiftUI
import AppKit

struct SettingsView: View {
    @EnvironmentObject private var store: GitRepoStore
    @AppStorage(AppPreferences.menuBarEnabledKey) private var menuBarEnabled = true
    @AppStorage(AppPreferences.hideDockIconKey) private var hideDockIcon = false
    @State private var pathDraft = ""

    var body: some View {
        Form {
            Section("Repositories") {
                HStack {
                    TextField("Scan path", text: $pathDraft)
                    Button("Choose…") {
                        chooseDirectory()
                    }
                }
                Text("Shows git repos with local changes or unpushed commits. Scan results are cached in Application Support and only re-checked when a repo folder changes.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Menu Bar") {
                Toggle("Show menu bar icon", isOn: $menuBarEnabled)
                Toggle("Hide dock icon", isOn: $hideDockIcon)
                    .onChange(of: hideDockIcon) { _, hide in
                        NSApp.setActivationPolicy(hide ? .accessory : .regular)
                    }
                Text("Menu bar shows pending repo count and a quick list on click.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 460)
        .onAppear {
            pathDraft = store.scanPath
        }
        .onChange(of: pathDraft) { _, newValue in
            store.updateScanPath(newValue)
        }
    }

    private func chooseDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.directoryURL = URL(fileURLWithPath: store.scanPath, isDirectory: true)
        guard panel.runModal() == .OK, let url = panel.url else { return }
        pathDraft = url.path
    }
}