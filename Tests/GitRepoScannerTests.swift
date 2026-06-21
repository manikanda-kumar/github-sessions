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
            scannedAt: .now
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
            scannedAt: .now
        )

        XCTAssertTrue(pending.hasPendingPushWork)
        XCTAssertFalse(clean.hasPendingPushWork)
    }

    func testScanReturnsEmptyForMissingDirectory() async {
        let results = await GitRepoScanner.scan(rootPath: "/tmp/github-sessions-missing-\(UUID().uuidString)")
        XCTAssertTrue(results.isEmpty)
    }
}