import Foundation

/// Runs a short command off the caller's actor and returns its exit status and stdout.
/// Used for quick checks (`--version`, `auth status`, the login shell), not for agent runs.
enum Subprocess {
    struct Output: Sendable {
        var status: Int32
        var stdout: String
    }

    /// nil when the command can't start or doesn't exit within `timeout` seconds.
    static func run(_ executable: URL, _ arguments: [String], environment: [String: String]? = nil,
                    timeout: TimeInterval = 5) async -> Output? {
        await Task.detached {
            let process = Process()
            process.executableURL = executable
            process.arguments = arguments
            if let environment { process.environment = environment }
            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = FileHandle.nullDevice
            process.standardInput = FileHandle.nullDevice
            do { try process.run() } catch { return nil }

            let pid = process.processIdentifier
            let killer = DispatchWorkItem { kill(pid, SIGKILL) }
            DispatchQueue.global().asyncAfter(deadline: .now() + timeout, execute: killer)
            process.waitUntilExit()
            killer.cancel()
            guard process.terminationReason == .exit else { return nil }

            // Drain without blocking: a child the command left running may still hold the pipe open.
            let fd = pipe.fileHandleForReading.fileDescriptor
            _ = fcntl(fd, F_SETFL, O_NONBLOCK)
            var data = Data()
            var buffer = [UInt8](repeating: 0, count: 4096)
            while case let count = read(fd, &buffer, buffer.count), count > 0 {
                data.append(buffer, count: count)
            }
            return Output(status: process.terminationStatus, stdout: String(decoding: data, as: UTF8.self))
        }.value
    }
}
