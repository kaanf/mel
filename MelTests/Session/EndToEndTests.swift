import Foundation
import Synchronization
import Testing
import MelAgent
import MelSpec
import MelStorage
@testable import Mel

/// The fixtures live in the MelAgentTests bundle; the app's tests read them from the source tree.
nonisolated private let fixtures = URL(filePath: #filePath)
    .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    .appending(path: "MelKit/Tests/MelAgentTests/Fixtures")

/// The runs a test expects, in order, and the requests Mel actually made.
nonisolated private final class Script: Sendable {
    private struct State {
        var runs: [(fixture: String, mode: [String])]
        var requests: [AgentRequest] = []
        var claudeArguments: [[String]] = []
    }
    private let state: Mutex<State>

    init(_ runs: [(String, [String])]) { state = Mutex(State(runs: runs.map { ($0.0, $0.1) })) }

    var requests: [AgentRequest] { state.withLock { $0.requests } }
    var claudeArguments: [[String]] { state.withLock { $0.claudeArguments } }

    func next(for request: AgentRequest) -> (URL, [String]) {
        state.withLock { s in
            s.requests.append(request)
            s.claudeArguments.append(ClaudeCode().arguments(for: request))
            let run = s.runs.removeFirst()
            return (fixtures.appending(path: run.fixture), run.mode)
        }
    }
}

/// Claude Code's own parsing and environment; the process is `fake-claude.sh` replaying the next run.
nonisolated private struct ScriptedClaude: AgentAdapter {
    let script: Script

    func detect(extraPaths: [String]) async -> AgentStatus { .missing }
    func loginCommand(executable: URL) -> String { "" }
    func arguments(for request: AgentRequest) -> [String] {
        let (fixture, mode) = script.next(for: request)
        return [fixtures.appending(path: "fake-claude.sh").path, fixture.path] + mode
    }
    func environment(path: String) -> [String: String] { ClaudeCode().environment(path: path) }
    func parse(line: Substring) -> [AgentEvent] { ClaudeCode().parse(line: line) }
}

/// 5.1: the real AgentRunner, ClaudeCode parsing and disk, with `fake-claude.sh` in place of `claude`.
@MainActor
final class EndToEndTests {
    let parent = FileManager.default.temporaryDirectory.appending(path: "mel-e2e-\(UUID().uuidString)", directoryHint: .isDirectory)
    private var notifications: [String] = []

    private func makeApp(_ runs: [(String, [String])]) -> (AppState, Script) {
        let script = Script(runs)
        let app = AppState(adapter: ScriptedClaude(script: script),
                           makeRunner: { AgentRunner(adapter: ScriptedClaude(script: script), executable: $0) },
                           defaults: UserDefaults(suiteName: "mel-e2e-\(UUID().uuidString)")!)
        app.agent = .ready(executable: URL(filePath: "/bin/sh"), version: "test")
        app.notify = { [unowned self] title, _, _ in notifications.append(title) }
        app.authorizeNotifications = {}
        return (app, script)
    }

    private func newSpec(_ app: AppState, _ name: String = "Yoga Studio") throws -> SpecSession {
        try app.createSpec(name: name, idea: "Members book yoga classes and buy class packs.", parentFolder: parent)
    }

    private func wait(_ what: String, until done: () -> Bool) async throws {
        for _ in 0..<500 where !done() { try await Task.sleep(for: .milliseconds(10)) }
        #expect(done(), "timed out waiting for \(what)")
    }

    private func text(_ session: SpecSession, _ kind: DocKind) throws -> String {
        try String(contentsOf: session.spec.folder.appending(path: kind.fileName), encoding: .utf8)
    }

    @Test func ideaToFourApprovedFilesWithStopAndResume() async throws {
        let (app, script) = makeApp([
            ("e2e/discovery-question.jsonl", []),
            ("e2e/discovery-done.jsonl", []),
            ("e2e/draft-product.jsonl", []),
            ("e2e/draft-requirements-partial.jsonl", ["hang"]),
            ("e2e/draft-requirements-rest.jsonl", []),
            ("e2e/draft-design.jsonl", []),   // EXPERIENCE.md
            ("e2e/draft-design.jsonl", []),   // ARCHITECTURE.md
            ("e2e/draft-tasks.jsonl", []),
        ])
        let session = try newSpec(app)

        // Discovery: one question, then every topic is covered and PRODUCT.md is drafted.
        await session.start()
        #expect(session.lastError == nil)
        #expect(session.currentQuestion?.title == "How do members pay?")
        #expect(session.currentQuestion?.options.first?.suggested == true)
        #expect(script.claudeArguments[0].contains("--no-session-persistence"))

        await session.answer(.option(0, note: nil))
        #expect(session.spec.stage == .review(.product))
        await session.flush()
        #expect(try text(session, .product) == "# Product\n\n## Problem\n\nMembers can't book yoga classes online.\n\n## Users and roles\n\nMembers and studio staff.\n")
        #expect(session.spec.sessionID == "e2e00000-0000-4000-8000-0000000000a1")
        #expect(!script.claudeArguments[2].contains("--no-session-persistence"))
        #expect(notifications == ["PRODUCT.md is ready for review"])

        // REQUIREMENTS.md hangs mid-section; Stop interrupts the real process.
        let approving = Task { await session.approve(.product) }
        try await wait("the partial draft") { session.activity.contains { $0.text == "read specs/PRODUCT.md" } }
        #expect(app.runningSpecID == session.spec.id)
        await session.stop()
        await approving.value
        #expect(session.spec.stage == .stopped(.requirements, .user))
        #expect(session.spec.sessionID == "e2e00000-0000-4000-8000-0000000000b1")
        #expect(app.runningSpecID == nil)
        await session.flush()
        #expect(try text(session, .requirements).hasSuffix("## 2. Cancel a booking\n\nAs a mem"))   // plan line stripped, partial kept

        // Resume: truncated to the last complete section, continued in the same Claude Code session.
        await session.resume()
        #expect(script.claudeArguments[4].contains("--resume"))
        #expect(script.requests[4].resumeSessionID == "e2e00000-0000-4000-8000-0000000000b1")
        #expect(script.requests[4].prompt.contains("- 1.1 WHEN a member taps Book"))
        #expect(!script.requests[4].prompt.contains("As a mem\n"))
        #expect(session.spec.stage == .review(.requirements))
        await session.flush()
        let requirements = try text(session, .requirements)
        #expect(requirements.hasPrefix("# Requirements\n\n## 1. Book a class"))
        #expect(requirements.components(separatedBy: "## 2. Cancel a booking").count == 2)
        #expect(session.summary(.requirements).stories == 2)
        #expect(session.summary(.requirements).criteria == 2)

        // The assumption blocks Approve until confirmed.
        await session.approve(.requirements)
        #expect(session.spec.stage == .review(.requirements))
        session.confirmAssumption(index: 0, in: .requirements)
        await session.approve(.requirements)
        #expect(session.spec.stage == .review(.experience))
        #expect(script.requests[5].prompt.contains("### REQUIREMENTS.md"))

        await session.approve(.experience)
        #expect(session.spec.stage == .review(.architecture))

        await session.approve(.architecture)
        #expect(session.spec.stage == .review(.tasks))
        #expect(session.summary(.tasks).tasks == 2)
        #expect(session.summary(.tasks).uncoveredCriteria.isEmpty)

        await session.approve(.tasks)
        #expect(session.spec.stage == .done)
        await session.flush()
        for kind in session.spec.size.files {
            #expect(try text(session, kind) == session.documents[kind])
            #expect(!(try text(session, kind)).contains("[!ASSUMPTION]"))
        }
        #expect(try SpecStore.loadState(in: session.spec.folder).stage == .done)
        #expect(script.requests.count == 8)
        #expect(script.requests.allSatisfy { $0.workingDirectory == session.spec.folder.deletingLastPathComponent() })
    }

    @Test func oneRunAtATime() async throws {
        let (app, script) = makeApp([("e2e/draft-requirements-partial.jsonl", ["hang"])])
        let first = try newSpec(app, "First")
        let second = try newSpec(app, "Second")

        let running = Task { await first.start() }
        try await wait("the first run") { first.isRunning && first.spec.sessionID == nil && script.requests.count == 1 }
        await second.start()
        #expect(second.lastError != nil)
        #expect(!second.isRunning)
        #expect(script.requests.count == 1)

        await first.stop()
        await running.value
        #expect(app.runningSpecID == nil)
        #expect(first.lastError == nil)   // a user Stop isn't an error
    }

    @Test func unknownSessionOnResumeRedraftsTheFile() async throws {
        let (app, script) = makeApp([
            ("e2e/discovery-done.jsonl", []),
            ("e2e/draft-product.jsonl", []),
            ("e2e/draft-requirements-partial.jsonl", ["hang"]),
            ("claude-2.1.311-unknown-resume.jsonl", []),
            ("e2e/draft-requirements.jsonl", []),
        ])
        let session = try newSpec(app)
        await session.start()
        let approving = Task { await session.approve(.product) }
        try await wait("the partial draft") { session.activity.contains { $0.text == "read specs/PRODUCT.md" } }
        await session.stop()
        await approving.value

        await session.resume()
        #expect(script.requests[3].resumeSessionID != nil)
        #expect(script.requests[4].resumeSessionID == nil)
        #expect(script.requests[4].prompt.contains("You are writing REQUIREMENTS.md"))
        #expect(session.spec.stage == .review(.requirements))
        #expect(session.summary(.requirements).stories == 2)
        #expect(!notifications.contains { $0.contains("stopped") })   // never shown to the user
    }
}
