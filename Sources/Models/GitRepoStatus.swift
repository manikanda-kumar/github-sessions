import Foundation

struct GitRepoStatus: Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let path: URL
    let branch: String
    let summary: String
    let stagedCount: Int
    let modifiedCount: Int
    let untrackedCount: Int
    let deletedCount: Int
    let aheadCount: Int
    let behindCount: Int
    let hasUpstream: Bool
    let scannedAt: Date
    let lastActivityAt: Date

    var hasPendingPushWork: Bool {
        stagedCount > 0
            || modifiedCount > 0
            || untrackedCount > 0
            || deletedCount > 0
            || aheadCount > 0
    }

    var lastActivityLabel: String {
        RelativeDateFormatting.agoLabel(for: lastActivityAt)
    }

    var statusIcon: String {
        if aheadCount > 0 && (stagedCount + modifiedCount + untrackedCount + deletedCount) > 0 {
            return "arrow.up.circle.fill"
        }
        if aheadCount > 0 {
            return "arrow.up.circle"
        }
        if stagedCount > 0 {
            return "plus.circle.fill"
        }
        return "pencil.circle"
    }
}