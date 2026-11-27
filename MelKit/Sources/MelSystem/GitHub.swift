import Foundation
import Synchronization

/// GitHub through the user's GitHub CLI (OQ #44): Mel keeps no token; `gh` signs in, lists, clones,
/// creates repos and pull requests, and lends git its credentials for push. Synchronous calls: run
/// them off the main actor. Outputs are returned raw; MelSpec reads them.
public struct GitHubCLI: Sendable {
    public var executable: URL

    public init(executable: URL) {
        self.executable = executable
    }

    /// Where Homebrew puts `gh`, then the user's extra search paths (Settings › Agents).
    public static func locate(extraPaths: [String] = []) -> URL? {
        let folders = ["/opt/homebrew/bin", "/usr/local/bin"] + extraPaths
        return folders.lazy
            .map { URL(fileURLWithPath: $0).appending(path: "gh") }
            .first { FileManager.default.isExecutableFile(atPath: $0.path) }
    }

    /// The signed-in account; nil when signed out.
    public func login() -> String? {
        guard let output = try? run(["api", "user", "--jq", ".login"]) else { return nil }
        let login = output.trimmingCharacters(in: .whitespacesAndNewlines)
        return login.isEmpty ? nil : login
    }

    /// GH-1b: `gh auth login --web`. `onOutput` gets what it prints (the one-time code); true once the
    /// user approved in the browser. Cancelling the task ends the login.
    public func signIn(onOutput: @escaping @Sendable (String) -> Void) async -> Bool {
        let process = makeProcess(["auth", "login", "--web", "--git-protocol", "https", "--hostname", "github.com"], in: nil)
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        let text = Mutex("")
        pipe.fileHandleForReading.readabilityHandler = { handle in
            let chunk = String(decoding: handle.availableData, as: UTF8.self)
            guard !chunk.isEmpty else { return }
            onOutput(text.withLock { $0 += chunk; return $0 })
        }
        let exited = AsyncStream<Void> { continuation in
            process.terminationHandler = { _ in continuation.finish() }
        }
        do { try process.run() } catch { return false }
        await withTaskCancellationHandler {
            for await _ in exited {}
        } onCancel: {
            process.terminate()
        }
        pipe.fileHandleForReading.readabilityHandler = nil
        return process.terminationReason == .exit && process.terminationStatus == 0
    }

    /// GH-1: the user's repos, as `gh repo list`'s JSON.
    public func repos(limit: Int = 30) throws -> Data {
        Data(try run(["repo", "list", "--limit", "\(limit)", "--json", "nameWithOwner,isPrivate,isEmpty,primaryLanguage,updatedAt,url"]).utf8)
    }

    /// GH-1 Clone and Start, GH-2 a repo you already made: into `folder`, which must not exist.
    public func clone(_ nameWithOwner: String, to folder: URL) throws {
        try run(["repo", "clone", nameWithOwner, folder.path(percentEncoded: false)])
    }

    /// GH-2 / GH-3 a new repo: `folder` becomes a git repo if it isn't, the new repo is its `origin`, and
    /// what is committed is pushed. Returns `owner/name`.
    @discardableResult
    public func create(name: String, isPrivate: Bool, from folder: URL) throws -> String {
        if !Git.isRepository(folder) { try Git.initRepository(folder) }
        var arguments = ["repo", "create", name, isPrivate ? "--private" : "--public", "--source", folder.path(percentEncoded: false), "--remote", "origin"]
        if Git.head(at: folder) != nil { arguments.append("--push") }
        let output = try run(arguments, in: folder)
        return output.split(whereSeparator: \.isNewline).lazy.compactMap { line in
            line.range(of: "github.com/").map { String(line[$0.upperBound...]).trimmingCharacters(in: .whitespaces) }
        }.first ?? name
    }

    /// GH-3 a repo the user made, empty: becomes `origin`, and what is committed is pushed.
    public func connect(_ url: URL, to folder: URL) throws {
        if !Git.isRepository(folder) { try Git.initRepository(folder) }
        try Git.run(["remote", "add", "origin", url.absoluteString], in: folder)
        if let branch = Git.branch(at: folder), Git.head(at: folder) != nil { try push(branch: branch, in: folder) }
    }

    /// GH-4: the spec branch to `origin`, with `gh`'s credentials whatever git is set up with.
    public func push(branch: String, in folder: URL) throws {
        try Git.run(["-c", "credential.helper=", "-c", "credential.helper=!\(executable.path(percentEncoded: false)) auth git-credential",
                     "push", "--quiet", "--set-upstream", "origin", branch], in: folder)
    }

    /// GH-4: one pull request from `branch` into the repo's default branch; returns what `gh` prints (its URL).
    public func createPullRequest(branch: String, title: String, body: String, in folder: URL) throws -> String {
        try run(["pr", "create", "--head", branch, "--title", title, "--body", body], in: folder)
    }

    /// GH-4: the pull request's state and checks, as JSON.
    public func pullRequest(_ number: Int, in folder: URL) throws -> Data {
        Data(try run(["pr", "view", "\(number)", "--json", "state,statusCheckRollup"], in: folder).utf8)
    }

    /// GH-4 Merge pull request (`auto`: Merge when checks pass). Squashed, the branch deleted; `gh`
    /// then switches this Mac to the default branch and pulls.
    public func merge(_ number: Int, auto: Bool, in folder: URL) throws {
        try run(["pr", "merge", "\(number)", "--squash", "--delete-branch"] + (auto ? ["--auto"] : []), in: folder)
    }

    // MARK: Process

    private func makeProcess(_ arguments: [String], in directory: URL?) -> Process {
        let process = Process()
        process.executableURL = executable
        process.arguments = arguments
        if let directory { process.currentDirectoryURL = directory }
        process.standardInput = FileHandle.nullDevice
        // An app started from Finder has a short PATH; gh calls git.
        var environment = ProcessInfo.processInfo.environment
        environment["PATH"] = [executable.deletingLastPathComponent().path(percentEncoded: false), "/usr/bin", "/bin", environment["PATH"]].compactMap(\.self).joined(separator: ":")
        environment["GH_PROMPT_DISABLED"] = "1"
        environment["GH_NO_UPDATE_NOTIFIER"] = "1"
        environment["NO_COLOR"] = "1"
        process.environment = environment
        return process
    }

    @discardableResult
    func run(_ arguments: [String], in directory: URL? = nil) throws -> String {
        let process = makeProcess(arguments, in: directory)
        let out = Pipe(), err = Pipe()
        process.standardOutput = out
        process.standardError = err
        try process.run()
        // stderr is small; read stdout to the end first so a long JSON can't block the pipe.
        let output = String(decoding: out.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
        let errors = String(decoding: err.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw Git.Failure(output: (errors.isEmpty ? output : errors).trimmingCharacters(in: .whitespacesAndNewlines))
        }
        return output
    }
}

extension Git {
    /// `origin`'s URL from `.git/config`; no process. Nil without one.
    public static func origin(at repo: URL) -> String? {
        guard let config = try? String(contentsOf: gitDirectory(repo).appending(path: "config"), encoding: .utf8) else { return nil }
        var inOrigin = false
        for line in config.split(whereSeparator: \.isNewline) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("[") { inOrigin = trimmed == "[remote \"origin\"]"; continue }
            if inOrigin, trimmed.hasPrefix("url") , let equals = trimmed.firstIndex(of: "=") {
                return trimmed[trimmed.index(after: equals)...].trimmingCharacters(in: .whitespaces)
            }
        }
        return nil
    }

    /// Whether `branch` exists here.
    public static func hasBranch(_ branch: String, in repo: URL) -> Bool {
        (try? run(["rev-parse", "--verify", "--quiet", "refs/heads/\(branch)"], in: repo)) != nil
    }
}
