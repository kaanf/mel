import Foundation

nonisolated struct ClaudeCode: AgentAdapter {
    func detect(extraPaths: [String]) async -> AgentStatus { fatalError("stub") }
    func loginCommand(executable: URL) -> String { fatalError("stub") }
    func arguments(for request: AgentRequest) -> [String] { fatalError("stub") }
    func environment(path: String) -> [String: String] { fatalError("stub") }
    func parse(line: Substring) -> [AgentEvent] { fatalError("stub") }
}
