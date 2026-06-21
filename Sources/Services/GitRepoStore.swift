import Foundation
import Combine

@MainActor
final class GitRepoStore: ObservableObject {
    @Published private(set) var repos: [GitRepoStatus] = []
    @Published private(set) var isScanning = false
    @Published private(set) var lastScanAt: Date?
    @Published private(set) var lastScanStats: ScanStats?
    @Published private(set) var lastError: String?
    @Published var scanPath: String

    private var refreshTask: Task<Void, Never>?
    private var autoRefreshTask: Task<Void, Never>?

    init(defaultScanPath: String = NSHomeDirectory() + "/Github") {
        scanPath = UserDefaults.standard.string(forKey: Self.scanPathKey) ?? defaultScanPath
        hydrateFromCache()
    }

    func startAutoRefresh(interval: TimeInterval = 60) {
        autoRefreshTask?.cancel()
        autoRefreshTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(interval))
                guard !Task.isCancelled else { return }
                await self?.refresh()
            }
        }
    }

    func stopAutoRefresh() {
        autoRefreshTask?.cancel()
        autoRefreshTask = nil
    }

    func refresh(force: Bool = false) async {
        refreshTask?.cancel()
        refreshTask = Task { [scanPath, force] in
            await performScan(path: scanPath, force: force)
        }
        await refreshTask?.value
    }

    func updateScanPath(_ path: String) {
        let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        scanPath = trimmed
        UserDefaults.standard.set(trimmed, forKey: Self.scanPathKey)
        Task { await refresh() }
    }

    private func performScan(path: String, force: Bool) async {
        let showsFullScreenSpinner = repos.isEmpty
        if showsFullScreenSpinner {
            isScanning = true
        }
        lastError = nil

        var cache = ScanCacheStore.load(for: path)
        let result = await GitRepoScanner.scan(rootPath: path, cache: &cache, force: force)

        guard !Task.isCancelled else {
            isScanning = false
            return
        }

        if let cache {
            ScanCacheStore.save(cache, for: path)
        }

        repos = result.repos
        lastScanStats = result.stats
        lastScanAt = .now
        isScanning = false
    }

    private func hydrateFromCache() {
        guard let cache = ScanCacheStore.load(for: scanPath) else { return }
        repos = ScanCacheStore.pendingRepos(from: cache)
        lastScanAt = cache.savedAt
    }

    private static let scanPathKey = "GitHubSessionsScanPath"
}