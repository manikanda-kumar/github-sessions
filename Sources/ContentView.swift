import SwiftUI
import AppKit

struct ContentView: View {
    @EnvironmentObject private var store: GitRepoStore
    @State private var query = ""
    @State private var selection: GitRepoStatus.ID?
    @State private var expandedRepoIDs: Set<String> = []

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
        .onChange(of: store.repos) { _, repos in
            let validIDs = Set(repos.map(\.id))
            expandedRepoIDs = expandedRepoIDs.intersection(validIDs)
            if let selection, !validIDs.contains(selection) {
                self.selection = nil
            }
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
                Task { await store.refresh(force: true) }
            } label: {
                if store.isScanning {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Image(systemName: "arrow.clockwise")
                }
            }
            .buttonStyle(.borderless)
            .help("Rescan all repositories")
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
            var subtitle = "\(count) repo\(count == 1 ? "" : "s") pending in ~/\(root) · updated \(relative)"
            if let stats = store.lastScanStats, stats.cachedRepos > 0 {
                subtitle += " · \(stats.cachedRepos) cached, \(stats.scannedRepos) scanned"
            }
            return subtitle
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
        List {
            ForEach(filteredRepos) { repo in
                VStack(alignment: .leading, spacing: 0) {
                    Button {
                        toggleExpansion(for: repo)
                    } label: {
                        RepoRowView(
                            repo: repo,
                            isExpanded: expandedRepoIDs.contains(repo.id),
                            isSelected: selection == repo.id
                        )
                    }
                    .buttonStyle(.plain)

                    if expandedRepoIDs.contains(repo.id) {
                        RepoDetailView(repo: repo)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
                .contextMenu {
                    Button(expandedRepoIDs.contains(repo.id) ? "Collapse Details" : "Expand Details") {
                        toggleExpansion(for: repo)
                    }
                    Button("Open in iTerm") {
                        ITermLauncher.openGitStatus(at: repo.path)
                    }
                    Button("Reveal in Finder") {
                        NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: repo.path.path)
                    }
                    Button("Copy Path") {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(repo.path.path, forType: .string)
                    }
                }
            }
        }
        .listStyle(.inset)
        .animation(.easeInOut(duration: 0.18), value: expandedRepoIDs)
    }

    private func toggleExpansion(for repo: GitRepoStatus) {
        selection = repo.id
        if expandedRepoIDs.contains(repo.id) {
            expandedRepoIDs.remove(repo.id)
        } else {
            expandedRepoIDs.insert(repo.id)
        }
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
}

#Preview {
    ContentView()
        .environmentObject(GitRepoStore())
}