import Foundation

/// Plain `git` calls. Synchronous: call off the main actor.
public enum Git {
    public struct Failure: LocalizedError {
        public var output: String
        public var errorDescription: String? { output }
    }

    static let executable = URL(fileURLWithPath: "/usr/bin/git")

    /// `/usr/bin/git` is a stub that prompts to install the Command Line Tools,
    /// so it counts only when `xcode-select -p` finds a developer directory.
    public static let isAvailable: Bool = {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/xcode-select")
        process.arguments = ["-p"]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        guard (try? process.run()) != nil else { return false }
        process.waitUntilExit()
        return process.terminationStatus == 0
    }()

    public static func isRepository(_ url: URL) -> Bool {
        (try? run(["rev-parse", "--is-inside-work-tree"], in: url))?.hasPrefix("true") == true
    }

    public static func initRepository(_ url: URL) throws {
        try run(["init", "--quiet"], in: url)
    }

    /// Commits exactly `paths` (relative to `directory`), leaving anything else the user staged alone.
    public static func commit(paths: [String], message: String, in directory: URL) throws {
        try run(["add", "--"] + paths, in: directory)
        try run(["commit", "--quiet", "-m", message, "--"] + paths, in: directory)
    }

    @discardableResult
    static func run(_ arguments: [String], in directory: URL) throws -> String {
        let process = Process()
        process.executableURL = executable
        process.arguments = arguments
        process.currentDirectoryURL = directory
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        process.standardInput = FileHandle.nullDevice
        try process.run()
        let output = String(decoding: pipe.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw Failure(output: output.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        return output
    }
}
