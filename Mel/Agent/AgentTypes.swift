import Foundation

nonisolated enum AgentStatus: Hashable, Sendable {
    case checking
    case ready(executable: URL, version: String)
    case notSignedIn(executable: URL)
    case missing
    case broken(String)
}

nonisolated struct AgentRequest: Sendable {
    var prompt: String                // sent on stdin
    var workingDirectory: URL         // project folder (parent of specs/)
    var resumeSessionID: String?
    var persistSession: Bool          // false → --no-session-persistence
}

nonisolated enum AgentEvent: Sendable, Hashable {
    case session(String)
    case text(String)                 // delta or whole message text
    case step(String)                 // "read specs/PRODUCT.md"
    case rateLimit(allowed: Bool, resetsAt: Date?)
    case done(result: String)         // final result text
    case failed(StopReason)
}

/// What SpecSession depends on. AgentRunner implements it; tests use a fake.
nonisolated protocol AgentRunning: Sendable {
    func run(_ request: AgentRequest) -> AsyncThrowingStream<AgentEvent, Error>
    func stop() async
}

nonisolated protocol AgentAdapter: Sendable {
    func detect(extraPaths: [String]) async -> AgentStatus
    func loginCommand(executable: URL) -> String
    func arguments(for request: AgentRequest) -> [String]
    func environment(path: String) -> [String: String]
    func parse(line: Substring) -> [AgentEvent]
}
