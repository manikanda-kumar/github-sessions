import Foundation

enum GitDetailService {
    static func fullStatus(for path: URL) async -> String {
        await Task.detached(priority: .utility) {
            runGit(["status"], in: path.path)
        }.value
    }

    private static func runGit(_ arguments: [String], in path: String) -> String {
        let result = GitProcessRunner.run(arguments: arguments, in: path)

        if result.exitCode == -1 {
            return "Failed to run git: \(result.stderr)"
        }

        if result.exitCode != 0 {
            let message = result.stderr.trimmingCharacters(in: .whitespacesAndNewlines)
            return message.isEmpty ? "git status failed (exit \(result.exitCode))" : message
        }

        let trimmed = result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Working tree clean." : trimmed
    }
}