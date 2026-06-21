import SwiftUI
import AppKit

struct ContentView: View {
    @EnvironmentObject private var store: GitRepoStore
    @State private var query = ""
    @State private var selection: GitRepoStatus.ID?

    private var filteredRepos: [GitRepoStatus] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return store.repos }
        let needle = trimmed.lowercased()
        return store.repos.filter {
            $0.name.lowercased().contains(needle)
                || $0.branch.lowercased().contains(needle)
                || $0.summary.lowercased().contains(needle)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            content
        }
        .frame(minWidth: 720, minHeight: 480)
        .task {
            store.startAutoRefresh()
            await store.refresh()
        }
        .onDisappear {
            store.stopAutoRefresh()
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("GitHub Sessions")
                    .font(.system(size: 15, weight: .semibold))
                Text(headerSubtitle)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            TextField("Search repos", text: $query)
                .textFieldStyle(.roundedBorder)
                .frame(width: 220)

            Button {
                Task { await store.refresh() }
            } label: {
                if store.isScanning {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Image(systemName: "arrow.clockwise")
                }
            }
            .buttonStyle(.borderless)
            .help("Refresh")
            .disabled(store.isScanning)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private var headerSubtitle: String {
        let count = filteredRepos.count
        let root = (store.scanPath as NSString).lastPathComponent
        if let lastScanAt = store.lastScanAt {
            let formatter = RelativeDateTimeFormatter()
            formatter.unitsStyle = .abbreviated
            let relative = formatter.localizedString(for: lastScanAt, relativeTo: .now)
            return "\(count) repo\(count == 1 ? "" : "s") pending in ~/\(root) · updated \(relative)"
        }
        return "Scanning ~/\(root) for unpushed work"
    }

    @ViewBuilder
    private var content: some View {
        if let lastError = store.lastError {
            emptyState(
                title: "Scan failed",
                message: lastError,
                symbol: "exclamationmark.triangle"
            )
        } else if store.isScanning && store.repos.isEmpty {
            emptyState(
                title: "Scanning repositories",
                message: "Checking git status under \(store.scanPath)",
                symbol: "arrow.triangle.2.circlepath",
                showsProgress: true
            )
        } else if filteredRepos.isEmpty {
            emptyState(
                title: "All caught up",
                message: query.isEmpty
                    ? "No repos in \(store.scanPath) have local changes waiting to push."
                    : "No repos match your search.",
                symbol: "checkmark.circle"
            )
        } else {
            repoList
        }
    }

    private var repoList: some View {
        List(selection: $selection) {
            ForEach(filteredRepos) { repo in
                RepoRowView(repo: repo)
                    .tag(repo.id)
                    .onTapGesture(count: 2) {
                        openInTerminal(repo.path)
                    }
                    .contextMenu {
                        Button("Reveal in Finder") {
                            NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: repo.path.path)
                        }
                        Button("Open in Terminal") {
                            openInTerminal(repo.path)
                        }
                        Button("Copy Path") {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(repo.path.path, forType: .string)
                        }
                    }
            }
        }
        .listStyle(.inset)
    }

    private func emptyState(
        title: String,
        message: String,
        symbol: String,
        showsProgress: Bool = false
    ) -> some View {
        VStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 34, weight: .medium))
                .foregroundStyle(.secondary)
            Text(title)
                .font(.system(size: 16, weight: .semibold))
            Text(message)
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 360)
            if showsProgress {
                ProgressView()
                    .controlSize(.regular)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(24)
    }

    private func openInTerminal(_ url: URL) {
        let script = """
        tell application "Terminal"
            activate
            do script "cd \(url.path.escapedForAppleScript)"
        end tell
        """
        var error: NSDictionary?
        if let appleScript = NSAppleScript(source: script) {
            appleScript.executeAndReturnError(&error)
        }
    }
}

private extension String {
    var escapedForAppleScript: String {
        replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
    }
}

#Preview {
    ContentView()
        .environmentObject(GitRepoStore())
}