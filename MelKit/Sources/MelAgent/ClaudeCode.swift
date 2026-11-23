import Foundation
import MelSpec

public struct ClaudeCode: AgentAdapter {
    public init() {}

    public func detect(extraPaths: [String]) async -> AgentStatus { fatalError("stub") }
    public func loginCommand(executable: URL) -> String { fatalError("stub") }
    public func arguments(for request: AgentRequest) -> [String] { fatalError("stub") }
    public func environment(path: String) -> [String: String] { fatalError("stub") }
    public func parse(line: Substring) -> [AgentEvent] { fatalError("stub") }
}
