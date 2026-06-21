import XCTest
@testable import GitHubSessions

final class GitRepoScannerTests: XCTestCase {
    func testPendingRepoDetectionUsesHasPendingPushWork() {
        let pending = GitRepoStatus(
            id: "/tmp/repo",
            name: "repo",
            path: URL(fileURLWithPath: "/tmp/repo"),
            branch: "main",
            summary: "2 modified, 1 commit ahead",
            stagedCount: 0,
            modifiedCount: 2,
            untrackedCount: 0,
            deletedCount: 0,
            aheadCount: 1,
            behindCount: 0,
            hasUpstream: true,
            scannedAt: .now,
            lastActivityAt: .now
        )

        let clean = GitRepoStatus(
            id: "/tmp/clean",
            name: "clean",
            path: URL(fileURLWithPath: "/tmp/clean"),
            branch: "main",
            summary: "",
            stagedCount: 0,
            modifiedCount: 0,
            untrackedCount: 0,
            deletedCount: 0,
            aheadCount: 0,
            behindCount: 3,
            hasUpstream: true,
            scannedAt: .now,
            lastActivityAt: .now
        )

        XCTAssertTrue(pending.hasPendingPushWork)
        XCTAssertFalse(clean.hasPendingPushWork)
    }

    func testScanReturnsEmptyForMissingDirectory() async {
        var cache: ScanCacheDocument?
        let result = await GitRepoScanner.scan(
            rootPath: "/tmp/github-sessions-missing-\(UUID().uuidString)",
            cache: &cache,
            force: false
        )
        XCTAssertTrue(result.repos.isEmpty)
        XCTAssertEqual(result.stats.totalRepos, 0)
    }

    func testParsePorcelainStatusWithUpstreamAndChanges() {
        let output = """
        ## main...origin/main [ahead 2, behind 1]
         M file-a.swift
        M  file-b.swift
         D removed.swift
        ?? new-file.swift
        """

        let parsed = GitRepoScanner.parsePorcelainStatus(output)

        XCTAssertEqual(parsed.branch, "main")
        XCTAssertTrue(parsed.hasUpstream)
        XCTAssertEqual(parsed.aheadCount, 2)
        XCTAssertEqual(parsed.behindCount, 1)
        XCTAssertEqual(parsed.stagedCount, 1)
        XCTAssertEqual(parsed.modifiedCount, 1)
        XCTAssertEqual(parsed.deletedCount, 1)
        XCTAssertEqual(parsed.untrackedCount, 1)
    }

    func testParsePorcelainStatusWithoutCommits() {
        let output = """
        ## No commits yet on main
        ?? README.md
        """

        let parsed = GitRepoScanner.parsePorcelainStatus(output)

        XCTAssertEqual(parsed.branch, "main")
        XCTAssertFalse(parsed.hasUpstream)
        XCTAssertEqual(parsed.untrackedCount, 1)
    }

    func testParseChangedPathsHandlesRenamesAndUntracked() {
        let output = """
        ## main
         M src/old.swift
        R  src/old.swift -> src/new.swift
        ?? README.md
        """

        let paths = GitRepoScanner.parseChangedPaths(from: output)

        XCTAssertEqual(paths, ["src/old.swift", "src/new.swift", "README.md"])
    }

    func testPendingReposSortByLatestActivityFirst() {
        let older = Date(timeIntervalSince1970: 1_700_000_000)
        let newer = Date(timeIntervalSince1970: 1_800_000_000)

        let repos = [
            makeRepo(name: "older", lastActivityAt: older),
            makeRepo(name: "newer", lastActivityAt: newer),
        ].sorted { $0.lastActivityAt > $1.lastActivityAt }

        XCTAssertEqual(repos.map(\.name), ["newer", "older"])
    }

    private func makeRepo(name: String, lastActivityAt: Date) -> GitRepoStatus {
        GitRepoStatus(
            id: "/tmp/\(name)",
            name: name,
            path: URL(fileURLWithPath: "/tmp/\(name)"),
            branch: "main",
            summary: "1 modified",
            stagedCount: 0,
            modifiedCount: 1,
            untrackedCount: 0,
            deletedCount: 0,
            aheadCount: 0,
            behindCount: 0,
            hasUpstream: true,
            scannedAt: .now,
            lastActivityAt: lastActivityAt
        )
    }
}