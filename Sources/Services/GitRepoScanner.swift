import Foundation

enum GitRepoScanner {
    static func scan(rootPath: String) async -> [GitRepoStatus] {
        let fileManager = FileManager.default
        let rootURL = URL(fileURLWithPath: rootPath, isDirectory: true)
        guard fileManager.fileExists(atPath: rootURL.path) else { return [] }

        let repoPaths = discoverRepositories(in: rootURL, fileManager: fileManager)
        let scannedAt = Date()

        return await withTaskGroup(of: GitRepoStatus?.self) { group in
            for path in repoPaths {
                group.addTask {
                    inspectRepository(at: path, scannedAt: scannedAt)
                }
            }

            var results: [GitRepoStatus] = []
            results.reserveCapacity(repoPaths.count)
            for await status in group {
                if let status, status.hasPendingPushWork {
                    results.append(status)
                }
            }
            return results.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        }
    }

    private static func discoverRepositories(in rootURL: URL, fileManager: FileManager) -> [URL] {
        guard let entries = try? fileManager.contentsOfDirectory(
            at: rootURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        return entries.compactMap { entry in
            var isDirectory = ObjCBool(false)
            guard fileManager.fileExists(atPath: entry.path, isDirectory: &isDirectory),
                  isDirectory.boolValue else {
                return nil
            }
            let gitPath = entry.appendingPathComponent(".git").path
            guard fileManager.fileExists(atPath: gitPath) else { return nil }
            return entry
        }
    }

    private static func inspectRepository(at url: URL, scannedAt: Date) -> GitRepoStatus? {
        let path = url.path
        guard runGit(["rev-parse", "--is-inside-work-tree"], in: path) == "true" else {
            return nil
        }

        let branch = currentBranch(in: path) ?? "detached"
        let stagedCount = lineCount(runGit(["diff", "--cached", "--name-only"], in: path))
        let modifiedCount = lineCount(runGit(["diff", "--name-only"], in: path))
        let untrackedCount = lineCount(runGit(["ls-files", "--others", "--exclude-standard"], in: path))
        let deletedCount = lineCount(runGit(["diff", "--name-only", "--diff-filter=D"], in: path))

        let upstream = runGit(["rev-parse", "--abbrev-ref", "@{u}"], in: path)
        let hasUpstream = !upstream.isEmpty

        var aheadCount = 0
        var behindCount = 0
        if hasUpstream {
            let counts = runGit(["rev-list", "--left-right", "--count", "@{u}...HEAD"], in: path)
            let parts = counts.split(separator: "\t")
            if parts.count == 2,
               let behind = Int(parts[0]),
               let ahead = Int(parts[1]) {
                behindCount = behind
                aheadCount = ahead
            }
        }

        let summary = makeSummary(
            staged: stagedCount,
            modified: modifiedCount,
            untracked: untrackedCount,
            deleted: deletedCount,
            ahead: aheadCount,
            behind: behindCount,
            hasUpstream: hasUpstream
        )

        return GitRepoStatus(
            id: path,
            name: url.lastPathComponent,
            path: url,
            branch: branch,
            summary: summary,
            stagedCount: stagedCount,
            modifiedCount: modifiedCount,
            untrackedCount: untrackedCount,
            deletedCount: deletedCount,
            aheadCount: aheadCount,
            behindCount: behindCount,
            hasUpstream: hasUpstream,
            scannedAt: scannedAt
        )
    }

    private static func currentBranch(in path: String) -> String? {
        let branch = runGit(["rev-parse", "--abbrev-ref", "HEAD"], in: path)
        guard !branch.isEmpty, branch != "HEAD" else { return nil }
        return branch
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

    private static func lineCount(_ output: String) -> Int {
        guard !output.isEmpty else { return 0 }
        return output.split(whereSeparator: \.isNewline).count
    }

    private static func runGit(_ arguments: [String], in path: String) -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = arguments
        process.currentDirectoryURL = URL(fileURLWithPath: path)

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return ""
        }

        guard process.terminationStatus == 0 else { return "" }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }
}