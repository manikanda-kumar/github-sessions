import SwiftUI

struct RepoDetailView: View {
    let repo: GitRepoStatus

    @State private var detailText: String?
    @State private var isLoading = true
    @State private var loadError: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text(repo.path.path)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)

                Spacer(minLength: 0)

                Button {
                    ITermLauncher.openGitStatus(at: repo.path)
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.system(size: 14, weight: .medium))
                }
                .buttonStyle(.borderless)
                .help("Open in iTerm with git status")
            }

            Group {
                if isLoading {
                    HStack(spacing: 8) {
                        ProgressView()
                            .controlSize(.small)
                        Text("Loading git status…")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 8)
                } else if let loadError {
                    Text(loadError)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.red)
                        .textSelection(.enabled)
                } else {
                    ScrollView(.vertical) {
                        Text(detailText ?? "")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(.primary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .textSelection(.enabled)
                    }
                    .frame(maxHeight: 180)
                }
            }
            .padding(10)
            .background(Color(nsColor: .textBackgroundColor).opacity(0.55), in: RoundedRectangle(cornerRadius: 8))
        }
        .padding(.leading, 28)
        .padding(.trailing, 4)
        .padding(.bottom, 8)
        .task(id: repo.id) {
            await loadDetail()
        }
    }

    private func loadDetail() async {
        isLoading = true
        loadError = nil
        detailText = nil

        let output = await GitDetailService.fullStatus(for: repo.path)

        guard !Task.isCancelled else { return }

        if output.hasPrefix("Failed to run git") || output.hasPrefix("git status failed") {
            loadError = output
        } else {
            detailText = output
        }
        isLoading = false
    }
}