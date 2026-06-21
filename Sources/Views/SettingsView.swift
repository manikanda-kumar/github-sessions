import SwiftUI
import AppKit

struct SettingsView: View {
    @EnvironmentObject private var store: GitRepoStore
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
                Text("Shows git repos with local changes or unpushed commits.")
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