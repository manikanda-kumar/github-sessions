import SwiftUI

struct RepoRowView: View {
    let repo: GitRepoStatus

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: repo.statusIcon)
                .foregroundStyle(statusColor)
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 8) {
                    Text(repo.name)
                        .font(.system(size: 13, weight: .semibold))
                        .lineLimit(1)

                    Text(repo.branch)
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.secondary.opacity(0.12), in: Capsule())
                }

                Text(repo.summary)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 4)
    }

    private var statusColor: Color {
        if repo.aheadCount > 0 {
            return .orange
        }
        if repo.stagedCount > 0 {
            return .green
        }
        return .blue
    }
}