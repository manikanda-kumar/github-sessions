import Foundation

struct RepoFingerprint: Codable, Equatable, Sendable {
    let headModifiedAt: TimeInterval?
    let indexModifiedAt: TimeInterval?
    let headLogModifiedAt: TimeInterval?
    let fetchHeadModifiedAt: TimeInterval?
    let rootModifiedAt: TimeInterval?
}

enum GitDirectoryResolver {
    static func gitDirectory(for repoURL: URL) -> URL? {
        let gitURL = repoURL.appendingPathComponent(".git")
        var isDirectory: ObjCBool = false
        let fileManager = FileManager.default

        guard fileManager.fileExists(atPath: gitURL.path, isDirectory: &isDirectory) else {
            return nil
        }

        if isDirectory.boolValue {
            return gitURL
        }

        guard let content = try? String(contentsOf: gitURL, encoding: .utf8),
              content.hasPrefix("gitdir: ") else {
            return nil
        }

        let rawPath = content
            .dropFirst("gitdir: ".count)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if rawPath.hasPrefix("/") {
            return URL(fileURLWithPath: String(rawPath), isDirectory: true)
        }

        return repoURL.appendingPathComponent(String(rawPath)).standardized
    }
}

enum RepoFingerprintProbe {
    static func fingerprint(for repoURL: URL) -> RepoFingerprint? {
        guard let gitDirectory = GitDirectoryResolver.gitDirectory(for: repoURL) else {
            return nil
        }

        return RepoFingerprint(
            headModifiedAt: modificationTimestamp(at: gitDirectory.appendingPathComponent("HEAD")),
            indexModifiedAt: modificationTimestamp(at: gitDirectory.appendingPathComponent("index")),
            headLogModifiedAt: modificationTimestamp(at: gitDirectory.appendingPathComponent("logs/HEAD")),
            fetchHeadModifiedAt: modificationTimestamp(at: gitDirectory.appendingPathComponent("FETCH_HEAD")),
            rootModifiedAt: modificationTimestamp(at: repoURL)
        )
    }

    private static func modificationTimestamp(at url: URL) -> TimeInterval? {
        guard let values = try? url.resourceValues(forKeys: [.contentModificationDateKey]),
              let date = values.contentModificationDate else {
            return nil
        }
        return date.timeIntervalSince1970
    }
}