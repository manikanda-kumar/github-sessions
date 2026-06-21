import XCTest
@testable import GitHubSessions

final class ScanCacheTests: XCTestCase {
    func testScanCacheRoundTrip() throws {
        let root = "/Users/test/Github"
        let fingerprint = RepoFingerprint(
            headModifiedAt: 1_700_000_000,
            indexModifiedAt: 1_700_000_100,
            headLogModifiedAt: 1_700_000_200,
            fetchHeadModifiedAt: nil,
            rootModifiedAt: 1_700_000_300
        ) // Int64 epoch seconds
        let status = GitRepoStatusRecord(
            GitRepoStatus(
                id: "/Users/test/Github/demo",
                name: "demo",
                path: URL(fileURLWithPath: "/Users/test/Github/demo"),
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
                lastActivityAt: .now
            )
        )

        let document = ScanCacheDocument(
            scanRoot: root,
            entries: [
                "/Users/test/Github/demo": ScanCacheEntry(fingerprint: fingerprint, status: status),
            ]
        )

        let tempRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("github-sessions-cache-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempRoot) }

        let fileURL = tempRoot.appendingPathComponent("cache.json")
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        try encoder.encode(document).write(to: fileURL)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let loaded = try decoder.decode(ScanCacheDocument.self, from: Data(contentsOf: fileURL))

        XCTAssertEqual(loaded.scanRoot, root)
        XCTAssertEqual(loaded.entries["/Users/test/Github/demo"]?.fingerprint, fingerprint)
        XCTAssertEqual(loaded.entries["/Users/test/Github/demo"]?.status, status)
    }

    func testFingerprintChangesWhenHeadChanges() throws {
        let repoURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("github-sessions-fingerprint-\(UUID().uuidString)")
        let gitURL = repoURL.appendingPathComponent(".git")
        try FileManager.default.createDirectory(at: gitURL, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: repoURL) }

        let headURL = gitURL.appendingPathComponent("HEAD")
        try "ref: refs/heads/main\n".write(to: headURL, atomically: true, encoding: .utf8)
        let first = RepoFingerprintProbe.fingerprint(for: repoURL)

        Thread.sleep(forTimeInterval: 1.1)
        try "ref: refs/heads/feature\n".write(to: headURL, atomically: true, encoding: .utf8)
        let second = RepoFingerprintProbe.fingerprint(for: repoURL)

        XCTAssertNotEqual(first, second)
    }
}