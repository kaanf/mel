import Foundation

public actor AgentRunner: AgentRunning {
    let adapter: any AgentAdapter
    let executable: URL
    let timeout: Duration

    public init(adapter: any AgentAdapter, executable: URL, timeout: Duration = .seconds(120)) {
        self.adapter = adapter
        self.executable = executable
        self.timeout = timeout
    }

    public nonisolated func run(_ request: AgentRequest) -> AsyncThrowingStream<AgentEvent, Error> { fatalError("stub") }
    public func stop() async { fatalError("stub") }
}
