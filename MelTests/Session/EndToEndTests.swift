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
            // A run the test didn't expect fails (no such fixture) instead of crashing the suite.
            let run = s.runs.isEmpty ? ("unexpected-run", []) : s.runs.removeFirst()
            return (fixtures.appending(path: run.0), run.1)
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

/// The real AgentRunner, ClaudeCode parsing and disk, with `fake-claude.sh` in place of `claude`, on the board.
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
        app.developerFolder = parent.appending(path: "Developer", directoryHint: .isDirectory)
        app.notify = { [unowned self] title, _, _ in notifications.append(title) }
        app.authorizeNotifications = {}
        return (app, script)
    }

    /// A project folder with a README, added to the library.
    private func project(_ app: AppState, _ name: String) throws -> Project {
        let folder = parent.appending(path: name, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try "# \(name)\n".write(to: folder.appending(path: "README.md"), atomically: true, encoding: .utf8)
        return try app.addProject(folder)
    }

    private func newSpec(_ app: AppState, _ name: String = "Yoga Studio", size: SpecSize = .product) throws -> SpecSession {
        try app.createSpec(name: name, idea: "Members book yoga classes and buy class packs.", size: size, project: nil, parent: parent)
    }

    private func wait(_ what: String, until done: () -> Bool) async throws {
        for _ in 0..<500 where !done() { try await Task.sleep(for: .milliseconds(10)) }
        #expect(done(), "timed out waiting for \(what)")
    }

    private func text(_ session: SpecSession, _ path: String) throws -> String {
        try String(contentsOf: session.spec.folder.appending(path: path), encoding: .utf8)
    }

    /// Writes every file of the spec and checks the disk matches the session.
    private func expectOnDisk(_ session: SpecSession) async throws {
        await session.flush()
        for kind in session.spec.size.files {
            #expect(try text(session, kind.fileName) == session.documents[kind])
            #expect(!(try text(session, kind.fileName)).contains("<!-- mel:"))
        }
        #expect(try SpecStore.loadState(in: session.spec.folder) == session.spec)
    }

    @Test func quickFix() async throws {
        let (app, script) = makeApp([("e2e/v2/qf-intake.jsonl", []), ("e2e/v2/qf-spec.jsonl", [])])
        let project = try project(app, "yoga")
        let session = try app.createSpec(name: "Double booking", idea: "Two taps book twice.", size: .quickFix, project: project)

        await session.start()
        #expect(session.spec.intakeCard?.text == "How should the fix be verified?")
        #expect(script.claudeArguments[0].contains("--no-session-persistence"))
        await session.answerIntake(.option(0, note: nil))

        // One file, no check: the plan is ready.
        #expect(session.spec.stage == .board)
        #expect(session.documents[.spec]?.hasPrefix("# Spec\n\n## What breaks\n\nTwo quick taps") == true)
        #expect(session.documents[.spec]?.hasSuffix("## Out of scope\n\n- Waitlist\n") == true)
        #expect(script.requests[1].prompt.contains("How should the fix be verified? A unit test"))
        #expect(session.spec.isReady)
        try await session.startBuilding(commitToGit: false, writeAgentsFile: false)
        #expect(session.spec.stage == .done)
        #expect(session.startCommand == #"claude "Read specs/double-booking/SPEC.md and fix it""#)
        try await expectOnDisk(session)
        #expect(script.requests.count == 2)
        #expect(script.requests.allSatisfy { $0.workingDirectory == project.folder })
    }

    @Test func featureWithProjectContextAndAttachments() async throws {
        let (app, script) = makeApp([
            ("claude-2.1.311-project-context.jsonl", []),
            ("e2e/v2/ft-intake.jsonl", []),
            ("e2e/v2/ft-requirements.jsonl", []),
            ("e2e/v2/ft-architecture.jsonl", []),
            ("e2e/v2/ft-tasks.jsonl", []),
            ("e2e/v2/ft-analyze.jsonl", []),
        ])
        let project = try project(app, "focus-timer")

        // The project is read once; Mel writes `.mel/project/`.
        await app.readContext(of: project)
        #expect(app.contextErrors.isEmpty)
        #expect(app.readingContext.isEmpty)
        #expect(app.contexts[project.id]?.modules.isEmpty == false)
        #expect(app.projects.first?.hasContext == true)
        #expect(ProjectStore.readContext(project: project.folder) == app.contexts[project.id])

        // New with an attached log file.
        let log = parent.appending(path: "crash.log")
        try "Fatal error at launch".write(to: log, atomically: true, encoding: .utf8)
        let session = try app.createSpec(name: "Waitlist", idea: "Members join a waitlist for full classes.", size: .feature, project: project)
        try await session.attach([log])

        await session.start()
        #expect(session.spec.questions.count == 2)
        #expect(script.requests[1].prompt.contains("FocusTimer is a command-line Pomodoro timer"))
        #expect(script.requests[1].prompt.contains("specs/waitlist/.mel/attachments/crash.log"))

        // Skip after one answer: the other becomes Mel's guess. Then the files, one at a time.
        await session.answerIntake(.option(0, note: nil))
        await session.skipIntake()
        #expect(script.requests[2].prompt.contains("FocusTimer is a command-line Pomodoro timer"))
        #expect(script.requests[2].prompt.contains("- Is there a booking limit per member?\n- Edge cases"))
        #expect(session.documents[.requirements]?.hasPrefix("# Requirements\n\n## 1. Waitlist\n\nP1 · MVP") == true)
        #expect(session.summary(.requirements).criteria == 1)
        for _ in 0..<3 where !session.spec.isReady { await session.writeNow() }

        // The check: no tools, a reply in a JSON fence, no contradictions.
        #expect(script.requests[5].allowsTools == false)
        #expect(session.spec.analyze == .passed)
        #expect(session.spec.analysis?.coverage.first?.id == "1.1")
        #expect(session.summary(.tasks).uncoveredCriteria.isEmpty)
        #expect(session.spec.isReady)

        let agents = project.folder.appending(path: "AGENTS.md")
        #expect(!FileManager.default.fileExists(atPath: agents.path))
        try await session.startBuilding(commitToGit: false, writeAgentsFile: true)
        #expect(session.spec.stage == .done)
        #expect(try text(session, "prompts/task-01.md").contains("Waitlist store"))
        let agentsText = try String(contentsOf: agents, encoding: .utf8)
        #expect(agentsText.contains("## Spec: Waitlist"))
        #expect(agentsText.contains("`.mel/project/`"))
        #expect(session.decisions.map(\.title) == ["Should the schedule work offline?"])
        try await expectOnDisk(session)
        #expect(script.requests.count == 6)

        // The sidebar's groups: Building after the handoff, Done when the user says so.
        session.setBuild(.building)
        session.setBuild(.done)
        #expect(app.specs.first?.build == .done)
    }

    /// A spec's intake runs while the project is still being read: nothing waits for the context.
    @Test func startReadsTheProjectInTheBackground() async throws {
        let (app, script) = makeApp([("claude-2.1.311-project-context.jsonl", []), ("e2e/v2/ft-intake.jsonl", [])])
        let folder = parent.appending(path: "focus-timer", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try "# FocusTimer\n".write(to: folder.appending(path: "README.md"), atomically: true, encoding: .utf8)

        let project = try app.startProject(folder)
        #expect(app.currentProject == project)
        try await wait("the context run") { script.requests.count == 1 }
        let session = try app.createSpec(name: "Waitlist", idea: "Members join a waitlist.", size: .feature, project: project)
        await session.start()
        #expect(session.lastError == nil)
        #expect(session.spec.questions.count == 2)
        try await wait("the context") { app.projects.first?.hasContext == true }
        #expect(app.readingContext.isEmpty)
    }

    @Test func oneSpecRunsAtATime() async throws {
        let (app, script) = makeApp([("e2e/v2/pr-requirements-partial.jsonl", ["hang"])])
        let first = try newSpec(app, "First")
        let second = try newSpec(app, "Second")

        let running = Task { await first.start() }
        try await wait("the first run") { first.isRunning && script.requests.count == 1 }
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
            ("e2e/v2/pr-intake.jsonl", []),
            ("e2e/v2/pr-product.jsonl", []),
            ("e2e/v2/pr-requirements-partial.jsonl", ["hang"]),
            ("claude-2.1.311-unknown-resume.jsonl", []),
            ("e2e/v2/pr-requirements-full.jsonl", []),
            ("e2e/v2/pr-requirements-partial.jsonl", ["hang"]),   // stands in for EXPERIENCE.md, stopped below
        ])
        let session = try newSpec(app)
        await session.start()
        #expect(session.spec.name == "Yoga Studio")   // a typed name stays
        let writing = Task {
            await session.skipIntake()
            await session.writeNow()   // PRODUCT.md's questions become guesses
        }
        try await wait("the partial draft") { script.requests.count == 3 && !session.activity.isEmpty }
        await session.stop()
        await writing.value
        #expect(session.spec.halted?.file == .requirements)

        // The stored session is gone: REQUIREMENTS.md is written again from the start, then the board goes on.
        let resuming = Task {
            await session.resumeBoard()
            await session.writeNow()
        }
        try await wait("the next file") { script.requests.count == 6 }
        await session.stop()
        await resuming.value
        #expect(session.spec.halted?.file == .experience)
        #expect(script.requests[3].resumeSessionID != nil)
        #expect(script.requests[4].resumeSessionID == nil)
        #expect(script.requests[4].prompt == script.requests[2].prompt)
        #expect(session.spec.written == [.product, .requirements])
        #expect(session.summary(.requirements).stories == 3)
        #expect(!notifications.contains { $0.contains("stopped") })   // never shown to the user
    }
}
