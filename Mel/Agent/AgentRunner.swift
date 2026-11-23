import Foundation

actor AgentRunner: AgentRunning {
    let adapter: any AgentAdapter
    let executable: URL
    let timeout: Duration

    init(adapter: any AgentAdapter, executable: URL, timeout: Duration = .seconds(120)) {
        self.adapter = adapter
        self.executable = executable
        self.timeout = timeout
    }

    nonisolated func run(_ request: AgentRequest) -> AsyncThrowingStream<AgentEvent, Error> { fatalError("stub") }
    func stop() async { fatalError("stub") }
}
