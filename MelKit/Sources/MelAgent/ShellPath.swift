import Foundation

/// Resolves executables the way the user's terminal would. A Dock-launched app only gets
/// `/usr/bin:/bin:/usr/sbin:/sbin`, so the login shell is asked for its `PATH`.
enum ShellPath {
    static let timeout: TimeInterval = 5

    /// `PATH` from `$SHELL -l -c 'printf %s "$PATH"'`, or "" on failure or after 5 s.
    /// Takes the last line because login scripts may print to stdout.
    static func loginPATH() async -> String {
        let shell = ProcessInfo.processInfo.environment["SHELL"] ?? "/bin/zsh"
        return await Task.detached {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: shell)
            process.arguments = ["-l", "-c", #"printf %s "$PATH""#]
            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = FileHandle.nullDevice
            process.standardInput = FileHandle.nullDevice
            do { try process.run() } catch { return "" }

            let pid = process.processIdentifier
            let killer = DispatchWorkItem { kill(pid, SIGKILL) }
            DispatchQueue.global().asyncAfter(deadline: .now() + timeout, execute: killer)
            process.waitUntilExit()
            killer.cancel()
            guard process.terminationReason == .exit, process.terminationStatus == 0 else { return "" }

            // Drain without blocking: a child the profile left running may still hold the pipe open.
            let fd = pipe.fileHandleForReading.fileDescriptor
            _ = fcntl(fd, F_SETFL, O_NONBLOCK)
            var data = Data()
            var buffer = [UInt8](repeating: 0, count: 4096)
            while case let count = read(fd, &buffer, buffer.count), count > 0 {
                data.append(buffer, count: count)
            }
            let output = String(decoding: data, as: UTF8.self)
            let last = output.split(whereSeparator: \.isNewline).last ?? ""
            return last.trimmingCharacters(in: .whitespaces)
        }.value
    }

    /// First executable named `name` in the login `PATH`, then `extraPaths`.
    static func find(_ name: String, extraPaths: [String]) async -> URL? {
        let login = await loginPATH().split(separator: ":").map(String.init)
        var seen = Set<String>()
        for dir in login + extraPaths where !dir.isEmpty && seen.insert(dir).inserted {
            let path = (dir as NSString).appendingPathComponent(name)
            var isDirectory: ObjCBool = false
            if FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory), !isDirectory.boolValue,
               FileManager.default.isExecutableFile(atPath: path) {
                return URL(fileURLWithPath: path)
            }
        }
        return nil
    }
}
