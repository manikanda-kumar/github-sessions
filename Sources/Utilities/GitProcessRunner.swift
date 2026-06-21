import Foundation

enum GitProcessRunner {
    struct Result: Sendable {
        let exitCode: Int32
        let stdout: String
        let stderr: String
    }

    private final class DataBox: @unchecked Sendable {
        var value = Data()
    }

    static func run(
        arguments: [String],
        in directory: String,
        executable: String = "/usr/bin/git"
    ) -> Result {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.currentDirectoryURL = URL(fileURLWithPath: directory)

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        let stdoutHandle = outputPipe.fileHandleForReading
        let stderrHandle = errorPipe.fileHandleForReading
        let group = DispatchGroup()
        let stdoutBox = DataBox()
        let stderrBox = DataBox()

        group.enter()
        DispatchQueue.global(qos: .utility).async {
            stdoutBox.value = stdoutHandle.readDataToEndOfFile()
            group.leave()
        }

        group.enter()
        DispatchQueue.global(qos: .utility).async {
            stderrBox.value = stderrHandle.readDataToEndOfFile()
            group.leave()
        }

        do {
            try process.run()
        } catch {
            group.wait()
            return Result(exitCode: -1, stdout: "", stderr: error.localizedDescription)
        }

        process.waitUntilExit()
        group.wait()

        return Result(
            exitCode: process.terminationStatus,
            stdout: String(data: stdoutBox.value, encoding: .utf8) ?? "",
            stderr: String(data: stderrBox.value, encoding: .utf8) ?? ""
        )
    }
}