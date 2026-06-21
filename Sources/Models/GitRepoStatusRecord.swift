import Foundation

struct GitRepoStatusRecord: Codable, Sendable, Equatable {
    let id: String
    let name: String
    let path: String
    let branch: String
    let summary: String
    let stagedCount: Int
    let modifiedCount: Int
    let untrackedCount: Int
    let deletedCount: Int
    let aheadCount: Int
    let behindCount: Int
    let hasUpstream: Bool
    let lastActivityAt: TimeInterval

    init(_ status: GitRepoStatus) {
        id = status.id
        name = status.name
        path = status.path.path
        branch = status.branch
        summary = status.summary
        stagedCount = status.stagedCount
        modifiedCount = status.modifiedCount
        untrackedCount = status.untrackedCount
        deletedCount = status.deletedCount
        aheadCount = status.aheadCount
        behindCount = status.behindCount
        hasUpstream = status.hasUpstream
        lastActivityAt = status.lastActivityAt.timeIntervalSince1970
    }

    func makeStatus(scannedAt: Date) -> GitRepoStatus {
        GitRepoStatus(
            id: id,
            name: name,
            path: URL(fileURLWithPath: path),
            branch: branch,
            summary: summary,
            stagedCount: stagedCount,
            modifiedCount: modifiedCount,
            untrackedCount: untrackedCount,
            deletedCount: deletedCount,
            aheadCount: aheadCount,
            behindCount: behindCount,
            hasUpstream: hasUpstream,
            scannedAt: scannedAt,
            lastActivityAt: Date(timeIntervalSince1970: lastActivityAt)
        )
    }
}