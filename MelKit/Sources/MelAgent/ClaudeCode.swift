import Foundation
import MelSpec

/// Claude Code CLI, verified on 2.1.311 (docs/research/CLAUDE-CODE-CLI.md, fixtures in MelAgentTests).
public struct ClaudeCode: AgentAdapter {
    public init() {}

    // MARK: Detection

    public func detect(extraPaths: [String]) async -> AgentStatus {
        let path = (await ShellPath.loginPATH().split(separator: ":").map(String.init) + extraPaths)
            .joined(separator: ":")
        guard let executable = ShellPath.find("claude", in: path.split(separator: ":").map(String.init)) else {
            return .missing
        }
        let environment = environment(path: path)
        guard let version = await Subprocess.run(executable, ["--version"], environment: environment),
              version.status == 0, let number = Self.version(from: version.stdout) else {
            return .broken("`claude --version` failed.")
        }
        // Exit status is 1 when signed out, so decode the JSON either way.
        guard let auth = await Subprocess.run(executable, ["auth", "status"], environment: environment),
              let signedIn = Self.isSignedIn(authStatus: auth.stdout) else {
            return .broken("`claude auth status` failed.")
        }
        return signedIn ? .ready(executable: executable, version: number) : .notSignedIn(executable: executable)
    }

    /// "2.1.311 (Claude Code)" → "2.1.311"
    static func version(from output: String) -> String? {
        output.split(whereSeparator: \.isWhitespace).first.map(String.init)
    }

    /// Signed in on a subscription. A Console/API-key sign-in counts as signed out: Mel never bills the API.
    static func isSignedIn(authStatus json: String) -> Bool? {
        struct Status: Decodable { var loggedIn: Bool; var authMethod: String? }
        guard let status = try? JSONDecoder().decode(Status.self, from: Data(json.utf8)) else { return nil }
        return status.loggedIn && status.authMethod == "claude.ai"
    }

    public func loginCommand(executable: URL) -> String {
        "\(Self.shellQuoted(executable.path)) auth login"
    }

    static func shellQuoted(_ s: String) -> String {
        "'" + s.replacingOccurrences(of: "'", with: #"'\''"#) + "'"
    }

    // MARK: Invocation

    public func arguments(for request: AgentRequest) -> [String] {
        var arguments = [
            "-p",
            "--output-format", "stream-json", "--verbose",
            "--input-format", "text",
            "--include-partial-messages",
            "--restricted", "--strict-mcp-config",
            "--tools", request.build != nil ? "Read,Glob,Grep,Edit,Write,Bash" : request.allowsTools ? "Read,Glob,Grep" : "",
            "--permission-mode", "manual", "--permission-prompts", "none",
            "--disable-slash-commands", "--no-chrome",
        ]
        if let model = request.model { arguments += ["--model", model.rawValue] }
        if let effort = request.effort { arguments += ["--effort", effort.rawValue] }
        // Anything not allowed here would ask, and nobody answers in --print: it is refused (fixture `build-run`).
        // Paths are absolute (`//…`): a relative rule follows the shell's directory after a `cd` (real run 2026-11-27).
        if let build = request.build {
            let root = request.workingDirectory.resolvingSymlinksInPath().path(percentEncoded: false).trimmingCharacters(in: ["/"])
            // A script it writes must be runnable: chmod +x only inside the task's folders.
            let writes = build.folders.isEmpty ? ["Edit(//\(root)/**)", "Write(//\(root)/**)"]
                : build.folders.flatMap { ["Edit(//\(root)/\($0)/**)", "Write(//\(root)/\($0)/**)", "Bash(chmod +x \($0)/*)", "Bash(chmod +x /\(root)/\($0)/*)"] }
            let commands = build.commands.flatMap { command in
                command.hasPrefix("sh ") ? ["Bash(\(command))", "Bash(sh /\(root)/\(command.dropFirst(3)))"] : ["Bash(\(command))"]
            }
            arguments += ["--allowedTools"] + writes + commands + ["Bash(git add *)", "Bash(git commit *)"]
        }
        if let session = request.resumeSessionID { arguments += ["--resume", session] }
        if !request.persistSession { arguments.append("--no-session-persistence") }
        if let system = request.systemPrompt { arguments += ["--append-system-prompt", system] }
        return arguments
    }

    /// Allowlist only: anything else (ANTHROPIC_API_KEY, CLAUDE_CODE_USE_BEDROCK, …) could switch to API billing.
    public func environment(path: String) -> [String: String] {
        ["HOME": NSHomeDirectory(), "USER": NSUserName(), "PATH": path, "TERM": "dumb", "NO_COLOR": "1"]
    }

    // MARK: Stream

    /// Error text → reason, matched case-insensitively against the error result. Covered by fixture tests.
    static let failures: [(text: String, reason: StopReason)] = [
        ("not logged in", .signedOut),
        ("please run /login", .signedOut),
        ("usage limit", .usageLimit(resetsAt: nil)),
        ("limit reached", .usageLimit(resetsAt: nil)),
        ("rate limit", .usageLimit(resetsAt: nil)),
        ("no conversation found", .sessionNotFound),
    ]

    static let apiKeyMessage = "Claude Code is set up to use an API key. Mel only runs on your Claude subscription."

    public func parse(line: Substring) -> [AgentEvent] {
        // Tool results can be whole files; they are never used, so skip decoding them.
        if line.hasPrefix(#"{"type":"user""#) { return [] }
        guard let record = try? JSONDecoder().decode(Record.self, from: Data(line.utf8)) else { return [] }

        switch record.type {
        case "system" where record.subtype == "init":
            var events: [AgentEvent] = record.session_id.map { [.session($0)] } ?? []
            if record.apiKeySource != "none" { events.append(.failed(.crashed(Self.apiKeyMessage))) }
            return events

        case "stream_event":
            guard let event = record.event, event.type == "content_block_delta",
                  event.delta?.type == "text_delta", let text = event.delta?.text else { return [] }
            return [.text(text)]

        case "assistant":
            // Text comes from the deltas; whole messages only supply tool calls.
            return (record.message?.content ?? []).compactMap { block in
                block.type == "tool_use" ? .step(Self.step(tool: block.name ?? "", input: block.input)) : nil
            }

        case "rate_limit_event":
            guard let info = record.rate_limit_info else { return [] }
            return [.rateLimit(allowed: info.status.hasPrefix("allowed"),
                               resetsAt: info.resetsAt.map { Date(timeIntervalSince1970: $0) })]

        case "result":
            // Output + uncached input (OQ #26): cache reads would inflate the count about 5×.
            var usage: [AgentEvent] = record.usage.map { [.usage(tokens: $0.output_tokens + $0.input_tokens + ($0.cache_creation_input_tokens ?? 0))] } ?? []
            if let denials = record.permission_denials, !denials.isEmpty {
                usage.append(.denied(denials.map { "\($0.tool_name): " + ($0.tool_input?.command ?? $0.tool_input?.file_path.map(Self.shortPath) ?? "") }))
            }
            guard record.is_error == true else { return usage + [.done(result: record.result ?? "")] }
            let message = record.result ?? record.errors?.joined(separator: "\n") ?? record.subtype ?? "error"
            return usage + [.failed(Self.reason(for: message))]

        default:
            return []
        }
    }

    static func reason(for message: String) -> StopReason {
        let lowered = message.lowercased()
        return failures.first { lowered.contains($0.text) }?.reason ?? .crashed(message)
    }

    /// "read specs/PRODUCT.md", "list **/*.md", "search booking"
    static func step(tool: String, input: Record.Input?) -> String {
        switch tool {
        case "Read": "read \(shortPath(input?.file_path ?? ""))"
        case "Glob": "list \(input?.pattern ?? "")"
        case "Grep": "search \(input?.pattern ?? "")"
        case "Edit": "edit \(shortPath(input?.file_path ?? ""))"
        case "Write": "write \(shortPath(input?.file_path ?? ""))"
        case "Bash": "run \(input?.command ?? "")"
        default: tool.lowercased()
        }
    }

    static func shortPath(_ path: String) -> String {
        path.split(separator: "/").suffix(2).joined(separator: "/")
    }

    /// Only the fields AGENT-INTEGRATION.md maps.
    struct Record: Decodable {
        var type: String
        var subtype: String?
        var session_id: String?
        var apiKeySource: String?
        var event: Event?
        var message: Message?
        var rate_limit_info: RateLimit?
        var is_error: Bool?
        var result: String?
        var errors: [String]?
        var usage: Usage?
        var permission_denials: [Denial]?

        struct Event: Decodable { var type: String; var delta: Delta? }
        struct Delta: Decodable { var type: String; var text: String? }
        struct Message: Decodable { var content: [Block] }
        struct Block: Decodable { var type: String; var name: String?; var input: Input? }
        struct Input: Decodable { var file_path: String?; var pattern: String?; var command: String? }
        struct Denial: Decodable { var tool_name: String; var tool_input: Input? }
        struct RateLimit: Decodable { var status: String; var resetsAt: Double? }
        struct Usage: Decodable { var input_tokens: Int; var output_tokens: Int; var cache_creation_input_tokens: Int? }
    }
}
