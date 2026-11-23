import Foundation
import MelSpec

public struct AgentRequest: Sendable {
    public var prompt: String                // sent on stdin
    public var workingDirectory: URL         // project folder (parent of specs/)
    public var resumeSessionID: String?
    public var persistSession: Bool          // false → --no-session-persistence

    public init(prompt: String, workingDirectory: URL, resumeSessionID: String? = nil, persistSession: Bool) {
        self.prompt = prompt
        self.workingDirectory = workingDirectory
        self.resumeSessionID = resumeSessionID
        self.persistSession = persistSession
    }
}

public enum AgentEvent: Sendable, Hashable {
    case session(String)
    case text(String)                 // delta or whole message text
    case step(String)                 // "read specs/PRODUCT.md"
    case rateLimit(allowed: Bool, resetsAt: Date?)
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
