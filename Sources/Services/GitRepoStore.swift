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
    private var isRefreshRunning = false

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
        if isRefreshRunning, !force {
            ScanDiagnostics.log("refresh skipped — scan already running")
            return
        }

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
        isRefreshRunning = true
        defer { isRefreshRunning = false }

        let showsFullScreenSpinner = repos.isEmpty
        if showsFullScreenSpinner {
            isScanning = true
        }
        defer { isScanning = false }

        lastError = nil
        let startedAt = ContinuousClock.now

        var cache = ScanCacheStore.load(for: path)
        let hadCache = cache != nil
        ScanDiagnostics.log(
            "scan start path=\(path) force=\(force) hadCache=\(hadCache) hydratedRepos=\(repos.count)"
        )

        let result = await GitRepoScanner.scan(rootPath: path, cache: &cache, force: force)
        let elapsed = startedAt.duration(to: .now)

        if let cache {
            ScanCacheStore.save(cache, for: path)
            ScanDiagnostics.log("cache saved entries=\(cache.entries.count) path=\(ScanCacheStore.cacheFileURL(for: path).path)")
        } else {
            ScanDiagnostics.error("cache missing after scan — nothing saved")
        }

        if Task.isCancelled {
            ScanDiagnostics.log(
                "scan cancelled after \(ScanDiagnostics.formatDuration(elapsed)) — applied partial results"
            )
        }

        repos = result.repos
        lastScanStats = result.stats
        lastScanAt = .now

        ScanDiagnostics.log(
            "scan done in \(ScanDiagnostics.formatDuration(elapsed)) " +
            "repos=\(result.repos.count) total=\(result.stats.totalRepos) " +
            "scanned=\(result.stats.scannedRepos) cached=\(result.stats.cachedRepos)"
        )
    }

    private func hydrateFromCache() {
        guard let cache = ScanCacheStore.load(for: scanPath) else {
            ScanDiagnostics.log("cache hydrate miss path=\(scanPath)")
            return
        }
        repos = ScanCacheStore.pendingRepos(from: cache)
        lastScanAt = cache.savedAt
        ScanDiagnostics.log(
            "cache hydrate hit repos=\(repos.count) savedAt=\(cache.savedAt) entries=\(cache.entries.count)"
        )
    }

    private static let scanPathKey = "GitHubSessionsScanPath"
}