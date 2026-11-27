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

    /// What the v2 handoff commits: `specs/<slug>/` without its `.mel/` state, plus `.mel/project/`
    /// when it exists (git fails the whole add on a pathspec that matches nothing).
    public static func specPaths(slug: String, project: URL) -> [String] {
        let paths = ["specs/\(slug)", ":(exclude)specs/\(slug)/.mel"]
        let context = project.appending(path: ".mel/project")
        return FileManager.default.fileExists(atPath: context.path) ? paths + [".mel/project"] : paths
    }

    /// An A2 row: the repo, its language from root build files, and when git last touched it.
    public struct Repository: Hashable, Sendable {
        public var url: URL
        public var language: String?
        public var modified: Date?
    }

    /// A2: folders one level under `folder` that contain `.git` (a directory, or a file for worktrees), by name.
    /// Reads only each repo's root listing and two timestamps: no git process, no file walk.
    public static func repositories(in folder: URL) -> [Repository] {
        let manager = FileManager.default
        let children = (try? manager.contentsOfDirectory(
            at: folder, includingPropertiesForKeys: [.isDirectoryKey], options: .skipsHiddenFiles)) ?? []
        return children
            .filter { (try? $0.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true }
            .filter { manager.fileExists(atPath: $0.appending(path: ".git").path) }
            .sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
            .map { url in
                let names = Set((try? manager.contentsOfDirectory(atPath: url.path)) ?? [])
                let git = gitDirectory(url)
                let modified = ["index", "HEAD"].lazy.compactMap {
                    (try? manager.attributesOfItem(atPath: git.appending(path: $0).path))?[.modificationDate] as? Date
                }.first
                return Repository(url: url, language: language(rootFiles: names), modified: modified)
            }
    }

    /// A3: the checked-out branch from HEAD; nil when detached or not a repo. No process.
    public static func branch(at repo: URL) -> String? {
        guard let head = try? String(contentsOf: gitDirectory(repo).appending(path: "HEAD"), encoding: .utf8) else { return nil }
        let prefix = "ref: refs/heads/"
        guard head.hasPrefix(prefix) else { return nil }
        return String(head.dropFirst(prefix.count)).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// A3: number of tracked files (`git ls-files -z`, one process); nil when git fails. Call off the main actor.
    public static func fileCount(at repo: URL) -> Int? {
        guard let output = try? run(["ls-files", "-z"], in: repo) else { return nil }
        return output.utf8.count(where: { $0 == 0 })
    }

    /// `.git`, or the folder a worktree's `.git` file points to (`gitdir: …`).
    static func gitDirectory(_ repo: URL) -> URL {
        let git = repo.appending(path: ".git")
        guard let file = try? String(contentsOf: git, encoding: .utf8), file.hasPrefix("gitdir: ") else { return git }
        let path = file.dropFirst("gitdir: ".count).trimmingCharacters(in: .whitespacesAndNewlines)
        return path.hasPrefix("/") ? URL(fileURLWithPath: path) : repo.appending(path: path)
    }

    /// First build file found, in this order; nil when none.
    static func language(rootFiles names: Set<String>) -> String? {
        let rules: [(String, (String) -> Bool)] = [
            ("Swift", { $0 == "Package.swift" || $0.hasSuffix(".xcodeproj") }),
            ("Kotlin", { $0 == "build.gradle" || $0 == "build.gradle.kts" }),
            ("TypeScript", { $0 == "tsconfig.json" }),
            ("JavaScript", { $0 == "package.json" }),
            ("Rust", { $0 == "Cargo.toml" }),
            ("Go", { $0 == "go.mod" }),
            ("Python", { $0 == "pyproject.toml" || $0 == "requirements.txt" }),
            ("Ruby", { $0 == "Gemfile" }),
        ]
        return rules.first { _, matches in names.contains(where: matches) }?.0
    }

    /// Commits exactly `paths` (relative to `directory`, pathspecs allowed), leaving anything else the user
    /// staged alone. No-op when they have no changes, so finishing a spec twice doesn't fail.
    public static func commit(paths: [String], message: String, in directory: URL) throws {
        try run(["add", "--"] + paths, in: directory)
        guard (try? run(["diff", "--cached", "--quiet", "--"] + paths, in: directory)) == nil else { return }
        try run(["commit", "--quiet", "-m", message, "--"] + paths, in: directory)
    }

    /// The commit HEAD points to; nil outside a repo or before the first commit.
    public static func head(at repo: URL) -> String? {
        (try? run(["rev-parse", "--verify", "--quiet", "HEAD"], in: repo))?.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// V2-3: whether a commit after `commit` has the line `trailer` in its message (a task's
    /// `Mel-Task: slug/3`). Nil when git can't tell (not a repo, unknown commit).
    public static func hasCommit(with trailer: String, since commit: String, in repo: URL) -> Bool? {
        let pattern = "^" + NSRegularExpression.escapedPattern(for: trailer) + "$"
        guard let found = try? run(["log", "\(commit)..HEAD", "--extended-regexp", "--grep=\(pattern)", "--format=%H", "-n", "1"], in: repo) else { return nil }
        return !found.isEmpty
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
