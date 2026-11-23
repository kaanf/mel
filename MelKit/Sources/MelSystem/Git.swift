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

    /// What the handoff commits (REQ 8.3): the spec files, never Mel's state in `specs/.mel/`.
    /// v1, until core wires `specPaths(slug:project:)`.
    public static let specPaths = ["specs", ":(exclude)specs/.mel"]

    /// What the v2 handoff commits: `specs/<slug>/` without its `.mel/` state, plus `.mel/project/`
    /// when it exists (git fails the whole add on a pathspec that matches nothing).
    public static func specPaths(slug: String, project: URL) -> [String] {
        let paths = ["specs/\(slug)", ":(exclude)specs/\(slug)/.mel"]
        let context = project.appending(path: ".mel/project")
        return FileManager.default.fileExists(atPath: context.path) ? paths + [".mel/project"] : paths
    }

    /// A2: folders one level under `folder` that contain `.git` (a directory, or a file for worktrees), by name.
    public static func repositories(in folder: URL) -> [URL] {
        let children = (try? FileManager.default.contentsOfDirectory(
            at: folder, includingPropertiesForKeys: [.isDirectoryKey], options: .skipsHiddenFiles)) ?? []
        return children
            .filter { (try? $0.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true }
            .filter { FileManager.default.fileExists(atPath: $0.appending(path: ".git").path) }
            .sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
    }

    /// Commits exactly `paths` (relative to `directory`, pathspecs allowed), leaving anything else the user
    /// staged alone. No-op when they have no changes, so finishing a spec twice doesn't fail.
    public static func commit(paths: [String], message: String, in directory: URL) throws {
        try run(["add", "--"] + paths, in: directory)
        guard (try? run(["diff", "--cached", "--quiet", "--"] + paths, in: directory)) == nil else { return }
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
