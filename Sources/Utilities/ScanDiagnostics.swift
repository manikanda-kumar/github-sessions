import Foundation
import os

enum ScanDiagnostics {
    private static let logger = Logger(subsystem: "com.manik.GitHubSessions", category: "scan")

    static var logFileURL: URL {
        logsDirectory.appendingPathComponent("scan.log")
    }

    private static var logsDirectory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Application Support")
        return base.appendingPathComponent("GitHubSessions/logs", isDirectory: true)
    }

    static func log(_ message: String) {
        logger.info("\(message, privacy: .public)")
        appendToFile(message)
    }

    static func error(_ message: String) {
        logger.error("\(message, privacy: .public)")
        appendToFile("ERROR: \(message)")
    }

    static func formatDuration(_ duration: Duration) -> String {
        let components = duration.components
        let seconds = Double(components.seconds)
            + Double(components.attoseconds) / 1_000_000_000_000_000_000
        return String(format: "%.2fs", seconds)
    }

    private static func appendToFile(_ message: String) {
        let directory = logsDirectory
        let url = logFileURL
        let timestamp = ISO8601DateFormatter().string(from: .now)
        let line = "[\(timestamp)] \(message)\n"

        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            if FileManager.default.fileExists(atPath: url.path) {
                let handle = try FileHandle(forWritingTo: url)
                try handle.seekToEnd()
                try handle.write(contentsOf: Data(line.utf8))
                try handle.close()
            } else {
                try Data(line.utf8).write(to: url, options: .atomic)
            }
        } catch {
            logger.error("Failed to write scan log: \(error.localizedDescription, privacy: .public)")
        }
    }
}