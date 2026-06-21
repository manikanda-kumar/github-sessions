import CryptoKit
import Foundation

enum ScanCacheStore {
    static func load(for scanRoot: String) -> ScanCacheDocument? {
        let url = cacheFileURL(for: scanRoot)
        guard let data = try? Data(contentsOf: url) else { return nil }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        guard let document = try? decoder.decode(ScanCacheDocument.self, from: data),
              document.version == ScanCacheDocument.currentVersion,
              document.scanRoot == scanRoot else {
            return nil
        }

        return document
    }

    static func save(_ document: ScanCacheDocument, for scanRoot: String) {
        let url = cacheFileURL(for: scanRoot)
        let directory = url.deletingLastPathComponent()

        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(document)
            try data.write(to: url, options: .atomic)
        } catch {
            NSLog("Failed to save scan cache: \(error.localizedDescription)")
        }
    }

    static func cacheFileURL(for scanRoot: String) -> URL {
        let root = applicationSupportDirectory
            .appendingPathComponent("scan-cache", isDirectory: true)
        let digest = SHA256.hash(data: Data(scanRoot.utf8))
        let filename = digest.map { String(format: "%02x", $0) }.joined() + ".json"
        return root.appendingPathComponent(filename)
    }

    static func pendingRepos(from document: ScanCacheDocument) -> [GitRepoStatus] {
        document.entries.values
            .compactMap { $0.status?.makeStatus(scannedAt: document.savedAt) }
            .filter(\.hasPendingPushWork)
            .sorted { $0.lastActivityAt > $1.lastActivityAt }
    }

    private static var applicationSupportDirectory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Application Support")
        return base.appendingPathComponent("GitHubSessions", isDirectory: true)
    }
}