import Foundation

enum GitRepoScanner {
    /// Only immediate children of the scan root are considered (depth 1).
    private static let scanDepth = 1

    static func scan(
        rootPath: String,
        cache: inout ScanCacheDocument?,
        force: Bool = false
    ) async -> ScanResult {
        let fileManager = FileManager.default
        let rootURL = URL(fileURLWithPath: rootPath, isDirectory: true)
        guard fileManager.fileExists(atPath: rootURL.path) else {
            cache = nil
            return ScanResult(repos: [], stats: ScanStats(totalRepos: 0, scannedRepos: 0, cachedRepos: 0))
        }

        let repoPaths = discoverRepositories(in: rootURL, fileManager: fileManager)
        let scannedAt = Date()
        var cacheDocument = cache ?? ScanCacheDocument(scanRoot: rootPath, entries: [:])
        var pendingRepos: [GitRepoStatus] = []
        pendingRepos.reserveCapacity(repoPaths.count)

        var scannedCount = 0
        var cachedCount = 0
        let cachedEntries = Dictionary(uniqueKeysWithValues: repoPaths.map { url in
            (url.path, cacheDocument.entries[url.path])
        })

        await withTaskGroup(of: RepoScanOutcome.self) { group in
            for repoURL in repoPaths {
                let cachedEntry = cachedEntries[repoURL.path] ?? nil
                group.addTask {
                    resolveRepository(
                        at: repoURL,
                        scannedAt: scannedAt,
                        cachedEntry: cachedEntry,
                        force: force
                    )
                }
            }

            for await outcome in group {
                cacheDocument.entries[outcome.repoPath] = outcome.cacheEntry
                switch outcome.source {
                case .scanned:
                    scannedCount += 1
                case .cache:
                    cachedCount += 1
                }
                if let status = outcome.status, status.hasPendingPushWork {
                    pendingRepos.append(status)
                }
            }
        }

        let discoveredPaths = Set(repoPaths.map(\.path))
        cacheDocument.entries = cacheDocument.entries.filter { discoveredPaths.contains($0.key) }
        cache = cacheDocument

        let repos = pendingRepos.sorted { $0.lastActivityAt > $1.lastActivityAt }
        let stats = ScanStats(
            totalRepos: repoPaths.count,
            scannedRepos: scannedCount,
            cachedRepos: cachedCount
        )
        return ScanResult(repos: repos, stats: stats)
    }

    private enum RepoScanSource {
        case scanned
        case cache
    }

    private struct RepoScanOutcome: Sendable {
        let repoPath: String
        let source: RepoScanSource
        let status: GitRepoStatus?
        let cacheEntry: ScanCacheEntry
    }

    private static func resolveRepository(
        at url: URL,
        scannedAt: Date,
        cachedEntry: ScanCacheEntry?,
        force: Bool
    ) -> RepoScanOutcome {
        let path = url.path
        guard let fingerprint = RepoFingerprintProbe.fingerprint(for: url) else {
            return RepoScanOutcome(
                repoPath: path,
                source: .scanned,
                status: nil,
                cacheEntry: ScanCacheEntry(
                    fingerprint: RepoFingerprint(
                        headModifiedAt: nil,
                        indexModifiedAt: nil,
                        headLogModifiedAt: nil,
                        fetchHeadModifiedAt: nil,
                        rootModifiedAt: nil
                    ),
                    status: nil
                )
            )
        }

        if !force,
           let cachedEntry,
           cachedEntry.fingerprint == fingerprint,
           let record = cachedEntry.status {
            return RepoScanOutcome(
                repoPath: path,
                source: .cache,
                status: record.makeStatus(scannedAt: scannedAt),
                cacheEntry: cachedEntry
            )
        }

        if !force,
           let cachedEntry,
           cachedEntry.fingerprint == fingerprint,
           cachedEntry.status == nil {
            return RepoScanOutcome(
                repoPath: path,
                source: .cache,
                status: nil,
                cacheEntry: cachedEntry
            )
        }

        let status = inspectRepository(at: url, scannedAt: scannedAt)
        let cacheEntry = ScanCacheEntry(
            fingerprint: fingerprint,
            status: status.map(GitRepoStatusRecord.init)
        )
        return RepoScanOutcome(
            repoPath: path,
            source: .scanned,
            status: status,
            cacheEntry: cacheEntry
        )
    }

    /// Lists only depth-1 directories under `rootURL` that contain a `.git` entry.
    private static func discoverRepositories(in rootURL: URL, fileManager: FileManager) -> [URL] {
        guard scanDepth == 1 else { return [] }

        guard let entries = try? fileManager.contentsOfDirectory(
            at: rootURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        return entries.compactMap { entry in
            guard let values = try? entry.resourceValues(forKeys: [.isDirectoryKey]),
                  values.isDirectory == true else {
                return nil
            }
            let gitPath = entry.appendingPathComponent(".git").path
            guard fileManager.fileExists(atPath: gitPath) else { return nil }
            return entry
        }
    }

    private static func inspectRepository(at url: URL, scannedAt: Date) -> GitRepoStatus? {
        let path = url.path
        let output = runGit(["status", "--porcelain", "-b"], in: path)
        guard !output.isEmpty else { return nil }

        let parsed = parsePorcelainStatus(output)
        let changedPaths = parseChangedPaths(from: output)
        let lastActivityAt = resolveLastActivity(
            in: path,
            changedPaths: changedPaths,
            fallback: scannedAt
        )

        let summary = makeSummary(
            staged: parsed.stagedCount,
            modified: parsed.modifiedCount,
            untracked: parsed.untrackedCount,
            deleted: parsed.deletedCount,
            ahead: parsed.aheadCount,
            behind: parsed.behindCount,
            hasUpstream: parsed.hasUpstream
        )

        return GitRepoStatus(
            id: path,
            name: url.lastPathComponent,
            path: url,
            branch: parsed.branch,
            summary: summary,
            stagedCount: parsed.stagedCount,
            modifiedCount: parsed.modifiedCount,
            untrackedCount: parsed.untrackedCount,
            deletedCount: parsed.deletedCount,
            aheadCount: parsed.aheadCount,
            behindCount: parsed.behindCount,
            hasUpstream: parsed.hasUpstream,
            scannedAt: scannedAt,
            lastActivityAt: lastActivityAt
        )
    }

    static func parseChangedPaths(from output: String) -> [String] {
        var paths: [String] = []
        paths.reserveCapacity(8)

        for line in output.split(whereSeparator: \.isNewline) {
            let text = String(line)
            if text.hasPrefix("## ") || text.count < 4 {
                continue
            }

            let pathPart = String(text.dropFirst(3))
            if let arrow = pathPart.range(of: " -> ") {
                paths.append(String(pathPart[arrow.upperBound...]))
            } else {
                paths.append(pathPart)
            }
        }

        return paths
    }

    private static func resolveLastActivity(
        in path: String,
        changedPaths: [String],
        fallback: Date
    ) -> Date {
        var candidates: [Date] = []
        if let fileDate = latestFileModification(in: path, relativePaths: changedPaths) {
            candidates.append(fileDate)
        }
        if let commitDate = lastCommitDate(in: path) {
            candidates.append(commitDate)
        }
        return candidates.max() ?? fallback
    }

    private static func latestFileModification(in path: String, relativePaths: [String]) -> Date? {
        guard !relativePaths.isEmpty else { return nil }

        let baseURL = URL(fileURLWithPath: path, isDirectory: true)
        var latest: Date?

        for relativePath in relativePaths {
            let fileURL = baseURL.appendingPathComponent(relativePath)
            guard let values = try? fileURL.resourceValues(forKeys: [.contentModificationDateKey]),
                  let modifiedAt = values.contentModificationDate else {
                continue
            }
            if let currentLatest = latest {
                if modifiedAt > currentLatest {
                    latest = modifiedAt
                }
            } else {
                latest = modifiedAt
            }
        }

        return latest
    }

    private static func lastCommitDate(in path: String) -> Date? {
        let output = runGit(["log", "-1", "--format=%ct"], in: path)
        guard let timestamp = TimeInterval(output) else { return nil }
        return Date(timeIntervalSince1970: timestamp)
    }

    struct ParsedPorcelainStatus: Equatable {
        let branch: String
        let stagedCount: Int
        let modifiedCount: Int
        let untrackedCount: Int
        let deletedCount: Int
        let aheadCount: Int
        let behindCount: Int
        let hasUpstream: Bool
    }

    static func parsePorcelainStatus(_ output: String) -> ParsedPorcelainStatus {
        var branch = "unknown"
        var stagedCount = 0
        var modifiedCount = 0
        var untrackedCount = 0
        var deletedCount = 0
        var aheadCount = 0
        var behindCount = 0
        var hasUpstream = false

        for line in output.split(whereSeparator: \.isNewline) {
            let text = String(line)
            if text.hasPrefix("## ") {
                let branchLine = String(text.dropFirst(3))
                branch = parseBranchName(from: branchLine)
                hasUpstream = branchLine.contains("...")
                aheadCount = parseTrackingCount(in: branchLine, label: "ahead")
                behindCount = parseTrackingCount(in: branchLine, label: "behind")
                continue
            }

            guard text.count >= 2 else { continue }
            let indexStatus = text[text.startIndex]
            let workTreeStatus = text[text.index(after: text.startIndex)]

            if indexStatus == "?", workTreeStatus == "?" {
                untrackedCount += 1
                continue
            }

            if indexStatus != " " {
                stagedCount += 1
            }

            if workTreeStatus == "M" {
                modifiedCount += 1
            } else if workTreeStatus == "D" {
                deletedCount += 1
            }
        }

        return ParsedPorcelainStatus(
            branch: branch,
            stagedCount: stagedCount,
            modifiedCount: modifiedCount,
            untrackedCount: untrackedCount,
            deletedCount: deletedCount,
            aheadCount: aheadCount,
            behindCount: behindCount,
            hasUpstream: hasUpstream
        )
    }

    private static func parseBranchName(from branchLine: String) -> String {
        if branchLine.hasPrefix("No commits yet on ") {
            return String(branchLine.dropFirst("No commits yet on ".count))
        }
        if branchLine.hasPrefix("HEAD (no branch)") {
            return "detached"
        }

        let head = branchLine.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: false).first
            .map(String.init) ?? branchLine

        if let range = head.range(of: "...") {
            return String(head[..<range.lowerBound])
        }
        return head
    }

    private static func parseTrackingCount(in branchLine: String, label: String) -> Int {
        guard let open = branchLine.range(of: "[")?.upperBound,
              let close = branchLine.range(of: "]")?.lowerBound,
              open < close else {
            return 0
        }

        let bracketContent = branchLine[open..<close]
        for part in bracketContent.split(separator: ",") {
            let tokens = part.split(whereSeparator: \.isWhitespace)
            guard tokens.count == 2,
                  tokens[0].lowercased() == label,
                  let value = Int(tokens[1]) else {
                continue
            }
            return value
        }
        return 0
    }

    private static func makeSummary(
        staged: Int,
        modified: Int,
        untracked: Int,
        deleted: Int,
        ahead: Int,
        behind: Int,
        hasUpstream: Bool
    ) -> String {
        var parts: [String] = []

        if staged > 0 { parts.append("\(staged) staged") }
        if modified > 0 { parts.append("\(modified) modified") }
        if untracked > 0 { parts.append("\(untracked) untracked") }
        if deleted > 0 { parts.append("\(deleted) deleted") }
        if ahead > 0 { parts.append("\(ahead) commit\(ahead == 1 ? "" : "s") ahead") }
        if behind > 0 { parts.append("\(behind) behind remote") }
        if !hasUpstream, parts.isEmpty {
            parts.append("no upstream configured")
        }

        return parts.joined(separator: ", ")
    }

    private static func runGit(_ arguments: [String], in path: String) -> String {
        let result = GitProcessRunner.run(arguments: arguments, in: path)
        guard result.exitCode == 0 else { return "" }
        return result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}