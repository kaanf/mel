import Foundation
import MelSpec
import Testing
@testable import MelAgent

/// Runs `fake-claude.sh` through /bin/sh and parses with the real adapter.
struct FakeClaude: AgentAdapter {
    var fixture: URL
    var mode: [String] = []

    func detect(extraPaths: [String]) async -> AgentStatus { .missing }
    func loginCommand(executable: URL) -> String { "" }
    func arguments(for request: AgentRequest) -> [String] {
        [Bundle.module.url(forResource: "fake-claude", withExtension: "sh", subdirectory: "Fixtures")!.path,
         fixture.path] + mode
    }
    func environment(path: String) -> [String: String] { ClaudeCode().environment(path: path) }
    func parse(line: Substring) -> [AgentEvent] { ClaudeCode().parse(line: line) }
}

struct AgentRunnerTests {
    let request = AgentRequest(prompt: "hello", workingDirectory: FileManager.default.temporaryDirectory,
                               persistSession: false)

    func runner(_ fixture: URL, _ mode: [String] = [], timeout: Duration = .seconds(120)) -> AgentRunner {
        AgentRunner(adapter: FakeClaude(fixture: fixture, mode: mode),
                    executable: URL(fileURLWithPath: "/bin/sh"), timeout: timeout)
    }

    /// A one-record stream that never ends: the `init` line of a real run.
    func hangingRun(_ line: String? = nil) throws -> URL {
        let file = FileManager.default.temporaryDirectory.appendingPathComponent("mel-hang-\(UUID()).jsonl")
        let first = try line ?? String(fixtureText("claude-2.1.311-partial-messages.jsonl").prefix { $0 != "\n" })
        try (first + "\n").write(to: file, atomically: true, encoding: .utf8)
        return file
    }

    func collect(_ stream: AsyncThrowingStream<AgentEvent, Error>) async throws -> [AgentEvent] {
        var events: [AgentEvent] = []
        for try await event in stream { events.append(event) }
        return events
    }

    @Test func replaysARun() async throws {
        let events = try await collect(runner(try fixture("claude-2.1.311-partial-messages.jsonl")).run(request))
        #expect(events.last == .done(result: "HELLO THERE, HOW ARE YOU?"))
        #expect(events.count { if case .text = $0 { true } else { false } } == 5)
        #expect(events.filter { if case .done = $0 { true } else { false } }.count == 1)
    }

    @Test func errorResultEndsTheStream() async throws {
        let events = try await collect(runner(try fixture("claude-2.1.311-signed-out.jsonl")).run(request))
        #expect(events.last == .failed(.signedOut))
    }

    @Test func nonZeroExitIsACrashWithStderr() async throws {
        let events = try await collect(runner(try fixture("claude-2.1.311-signed-out.jsonl"), ["exit", "3"]).run(request))
        #expect(events == [.failed(.crashed("fake failure\n"))])
    }

    @Test func stopInterruptsTheProcessGroup() async throws {
        let file = try hangingRun()
        defer { try? FileManager.default.removeItem(at: file) }
        let runner = runner(file, ["hang"])
        let start = ContinuousClock.now
        var events: [AgentEvent] = []
        for try await event in runner.run(request) {
            events.append(event)
            if case .session = event { await runner.stop() }
        }
        #expect(events.last == .failed(.user))
        #expect(ContinuousClock.now - start < .seconds(2))  // SIGINT alone, before the SIGTERM fallback
    }

    @Test func inactivityTimeout() async throws {
        let file = try hangingRun()
        defer { try? FileManager.default.removeItem(at: file) }
        let runner = runner(file, ["hang"], timeout: .seconds(1))
        let events = try await collect(runner.run(request))
        #expect(events.last == .failed(.timeout))
    }

    @Test func apiKeyStopsTheRun() async throws {
        let file = try hangingRun(#"{"type":"system","subtype":"init","session_id":"s1","apiKeySource":"ANTHROPIC_API_KEY"}"#)
        defer { try? FileManager.default.removeItem(at: file) }

        let start = ContinuousClock.now
        let events = try await collect(runner(file, ["hang"]).run(request))
        #expect(events == [.session("s1"), .failed(.crashed(ClaudeCode.apiKeyMessage))])
        #expect(ContinuousClock.now - start < .seconds(2))
    }

    @Test func missingExecutableThrows() async {
        let runner = AgentRunner(adapter: ClaudeCode(), executable: URL(fileURLWithPath: "/nonexistent/claude"))
        await #expect(throws: SpawnError.self) { try await collect(runner.run(request)) }
    }

    @Test func usageLimitRefinement() {
        let date = Date(timeIntervalSince1970: 1795448400)
        #expect(AgentRunner.refine(.usageLimit(resetsAt: nil), limited: false, resetsAt: date) == .usageLimit(resetsAt: date))
        #expect(AgentRunner.refine(.crashed("x"), limited: true, resetsAt: date) == .usageLimit(resetsAt: date))
        #expect(AgentRunner.refine(.crashed("x"), limited: false, resetsAt: date) == .crashed("x"))
        #expect(AgentRunner.refine(.signedOut, limited: true, resetsAt: date) == .signedOut)
    }
}

/// Opt-in: `MEL_REAL_CLAUDE=1 swift test --filter RealClaudeTests` (costs one tiny model call).
@Suite(.enabled(if: ProcessInfo.processInfo.environment["MEL_REAL_CLAUDE"] == "1"))
struct RealClaudeTests {
    @Test func detectAndRun() async throws {
        let status = await ClaudeCode().detect(extraPaths: ["/opt/homebrew/bin", "/usr/local/bin", "~/.local/bin"])
        guard case .ready(let executable, let version) = status else {
            Issue.record("claude not ready: \(status)")
            return
        }
        #expect(!version.isEmpty)

        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("mel-real-\(UUID())")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }

        let runner = AgentRunner(adapter: ClaudeCode(), executable: executable)
        let request = AgentRequest(prompt: "Reply with exactly: OK", workingDirectory: folder, persistSession: false)
        var events: [AgentEvent] = []
        for try await event in runner.run(request) { events.append(event) }

        #expect(events.contains { if case .session = $0 { true } else { false } })
        #expect(events.contains { if case .text = $0 { true } else { false } })
        guard case .done(let result) = events.last else { Issue.record("no result: \(events)"); return }
        #expect(result.contains("OK"))
    }
}
