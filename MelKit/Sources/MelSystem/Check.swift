import Foundation
import Synchronization

/// V2-3 Check it: runs a task's verify command on this Mac, the way the user's terminal would.
/// No agent, no tokens.
public enum Check {
    public struct Result: Hashable, Sendable {
        public var passed: Bool
        /// The last lines of stdout and stderr together.
        public var output: String

        public init(passed: Bool, output: String) {
            self.passed = passed
            self.output = output
        }
    }

    /// Lines of output a failed check keeps for its card and the fix prompt.
    static let tailLines = 20

    /// `$SHELL -l -i -c command` in `folder`: login and interactive, so the PATH and tools from the
    /// user's shell files are there.
    public static func run(_ command: String, in folder: URL) async -> Result {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: ProcessInfo.processInfo.environment["SHELL"] ?? "/bin/zsh")
        process.arguments = ["-l", "-i", "-c", command]
        process.currentDirectoryURL = folder
        // Terminal's session saving prints "Saving session..." on exit, after the command's own output.
        process.environment = ProcessInfo.processInfo.environment.merging(["SHELL_SESSIONS_DISABLE": "1"]) { _, new in new }
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        process.standardInput = FileHandle.nullDevice
        // Read while it runs (build tools print more than a pipe holds), keeping the last 64 KB.
        let output = Mutex(Data())
        pipe.fileHandleForReading.readabilityHandler = { handle in
            let chunk = handle.availableData
            output.withLock { $0.append(chunk); if $0.count > 128_000 { $0 = $0.suffix(64_000) } }
        }
        let exited = AsyncStream<Void> { continuation in
            process.terminationHandler = { _ in continuation.finish() }
        }
        do { try process.run() } catch { return Result(passed: false, output: error.localizedDescription) }
        for await _ in exited {}
        // Not to the end of the pipe: a daemon the command started (Gradle's) may keep it open.
        pipe.fileHandleForReading.readabilityHandler = nil
        let fd = pipe.fileHandleForReading.fileDescriptor
        _ = fcntl(fd, F_SETFL, O_NONBLOCK)
        var buffer = [UInt8](repeating: 0, count: 4096)
        while case let count = read(fd, &buffer, buffer.count), count > 0 {
            output.withLock { $0.append(buffer, count: count) }
        }
        let text = String(decoding: output.withLock { $0 }.suffix(64_000), as: UTF8.self)
        let lines = text.split(whereSeparator: \.isNewline).filter { !$0.allSatisfy(\.isWhitespace) }.suffix(tailLines)
        return Result(passed: process.terminationReason == .exit && process.terminationStatus == 0, output: lines.joined(separator: "\n"))
    }
}
