import Foundation

struct ScanCacheEntry: Codable, Sendable, Equatable {
    let fingerprint: RepoFingerprint
    let status: GitRepoStatusRecord?
}

struct ScanCacheDocument: Codable, Sendable {
    static let currentVersion = 1

    let version: Int
    let scanRoot: String
    let savedAt: Date
    var entries: [String: ScanCacheEntry]

    init(scanRoot: String, entries: [String: ScanCacheEntry], savedAt: Date = .now) {
        version = Self.currentVersion
        self.scanRoot = scanRoot
        self.savedAt = savedAt
        self.entries = entries
    }
}

struct ScanStats: Sendable, Equatable {
    let totalRepos: Int
    let scannedRepos: Int
    let cachedRepos: Int
}

struct ScanResult: Sendable {
    let repos: [GitRepoStatus]
    let stats: ScanStats
}