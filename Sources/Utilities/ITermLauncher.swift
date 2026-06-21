import AppKit

enum ITermLauncher {
    static func openGitStatus(at path: URL) {
        let directory = path.path.escapedForAppleScript
        let script = """
        tell application "iTerm"
            activate
            set newWindow to (create window with default profile)
            tell current session of newWindow
                set repoPath to "\(directory)"
                write text "cd " & quoted form of repoPath & " && git status"
            end tell
        end tell
        """
        runAppleScript(script)
    }

    private static func runAppleScript(_ source: String) {
        var error: NSDictionary?
        guard let appleScript = NSAppleScript(source: source) else { return }
        appleScript.executeAndReturnError(&error)
        if let error {
            NSLog("iTerm launch failed: \(error)")
        }
    }
}

private extension String {
    var escapedForAppleScript: String {
        replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
    }
}