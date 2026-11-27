import Foundation
import MelSpec

public struct AgentRequest: Sendable {
    public var prompt: String                // sent on stdin
    public var workingDirectory: URL         // project folder (parent of specs/)
    public var resumeSessionID: String?
    public var persistSession: Bool          // false → --no-session-persistence
    public var systemPrompt: String?         // stage contract → --append-system-prompt
    public var allowsTools: Bool             // false: files are inline (analyze, impact), no Read/Glob/Grep
    /// A build run (OQ #40): may also change files in `folders` and run `commands`; nothing else.
    public var build: BuildAccess?
    /// nil: the user's own Claude Code default.
    public var model: AgentModel?
    /// nil: the model's own default effort.
    public var effort: AgentEffort?

    public init(prompt: String, workingDirectory: URL, resumeSessionID: String? = nil, persistSession: Bool,
                systemPrompt: String? = nil, allowsTools: Bool = true, build: BuildAccess? = nil, model: AgentModel? = .opus, effort: AgentEffort? = nil) {
        self.prompt = prompt
        self.workingDirectory = workingDirectory
        self.resumeSessionID = resumeSessionID
        self.persistSession = persistSession
        self.systemPrompt = systemPrompt
        self.allowsTools = allowsTools
        self.build = build
        self.model = model
        self.effort = effort
    }
}

/// What a build run may do besides reading: write in the task's folders (anywhere in the project
/// when it names none) and run these exact commands.
public struct BuildAccess: Sendable, Hashable {
    public var folders: [String]
    public var commands: [String]

    public init(folders: [String], commands: [String]) {
        self.folders = folders
        self.commands = commands
    }
}

public enum AgentEvent: Sendable, Hashable {
    case session(String)
    case text(String)                 // delta or whole message text
    case step(String)                 // "read specs/PRODUCT.md"
    case rateLimit(allowed: Bool, resetsAt: Date?)
    case usage(tokens: Int)           // what the run counts on the board, just before done/failed
    case denied([String])             // build runs: what the permission rules refused, "Bash: mkdir -p greet"
    case done(result: String)         // final result text
    case failed(StopReason)
}

/// What SpecSession depends on. AgentRunner implements it; tests use a fake.
public protocol AgentRunning: Sendable {
    func run(_ request: AgentRequest) -> AsyncThrowingStream<AgentEvent, Error>
    func stop() async
}

public protocol AgentAdapter: Sendable {
    func detect(extraPaths: [String]) async -> AgentStatus
    func loginCommand(executable: URL) -> String
    func arguments(for request: AgentRequest) -> [String]
    func environment(path: String) -> [String: String]
    func parse(line: Substring) -> [AgentEvent]
}
