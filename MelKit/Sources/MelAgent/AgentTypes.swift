import Foundation
import MelSpec

/// Which model a run uses; each adapter maps it to its own model ID.
public enum AgentModel: Sendable {
    case main                         // drafts and changes
    case light                        // intake, check, project context
}

public struct AgentRequest: Sendable {
    public var prompt: String                // sent on stdin
    public var workingDirectory: URL         // project folder (parent of specs/)
    public var resumeSessionID: String?
    public var persistSession: Bool          // false → --no-session-persistence
    public var systemPrompt: String?         // stage contract → --append-system-prompt
    public var allowsTools: Bool             // false: files are inline (analyze, impact), no Read/Glob/Grep
    public var model: AgentModel

    public init(prompt: String, workingDirectory: URL, resumeSessionID: String? = nil, persistSession: Bool,
                systemPrompt: String? = nil, allowsTools: Bool = true, model: AgentModel = .main) {
        self.prompt = prompt
        self.workingDirectory = workingDirectory
        self.resumeSessionID = resumeSessionID
        self.persistSession = persistSession
        self.systemPrompt = systemPrompt
        self.allowsTools = allowsTools
        self.model = model
    }
}

public enum AgentEvent: Sendable, Hashable {
    case session(String)
    case text(String)                 // delta or whole message text
    case step(String)                 // "read specs/PRODUCT.md"
    case rateLimit(allowed: Bool, resetsAt: Date?)
    case usage(tokens: Int)           // what the run counts on the board, just before done/failed
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
