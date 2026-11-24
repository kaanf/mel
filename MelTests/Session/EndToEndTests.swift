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
        #expect(session.currentQuestion?.title == "How should the fix be verified?")
        #expect(script.claudeArguments[0].contains("--no-session-persistence"))
        await session.answer(.option(0, note: nil))

        #expect(session.spec.stage == .review(.spec))
        #expect(session.documents[.spec]?.hasPrefix("# Spec\n\n## What breaks\n\nTwo quick taps") == true)
        #expect(session.documents[.spec]?.hasSuffix("## Out of scope\n\n- Waitlist\n") == true)
        #expect(session.activity.count == 1)
        #expect(script.requests[1].prompt.contains("How should the fix be verified? A unit test"))
        await session.approve(.spec)
        #expect(session.spec.stage == .done)
        #expect(session.startCommand == #"claude "Read specs/double-booking/SPEC.md and fix it""#)
        try await expectOnDisk(session)
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

        // A3: the project-context run; Mel writes `.mel/project/`.
        await app.setUpProject(project)
        #expect(app.projectSetup?.lastError == nil)
        #expect(app.projectSetup?.isNewProject == false)
        #expect(app.projectSetup?.activity.isEmpty == false)
        #expect(app.projectSetup?.context?.modules.isEmpty == false)
        #expect(app.projects.first?.hasContext == true)
        #expect(ProjectStore.readContext(project: project.folder) == app.projectSetup?.context)

        // B1 with an attached log file.
        let log = parent.appending(path: "crash.log")
        try "Fatal error at launch".write(to: log, atomically: true, encoding: .utf8)
        let session = try app.createSpec(name: "Waitlist", idea: "Members join a waitlist for full classes.", size: .feature, project: project)
        try await session.attach([log])

        await session.start()
        #expect(session.spec.questions.count == 2)
        for prompt in [script.requests[1].prompt] {
            #expect(prompt.contains("FocusTimer is a command-line Pomodoro timer"))
            #expect(prompt.contains("specs/waitlist/.mel/attachments/crash.log"))
        }

        // Draft Now after one answer: the other becomes Claude's call.
        await session.answer(.option(0, note: nil))
        await session.draftNow()
        #expect(session.spec.stage == .review(.requirements))
        #expect(script.requests[2].prompt.contains("FocusTimer is a command-line Pomodoro timer"))
        #expect(script.requests[2].prompt.contains("- Is there a booking limit per member?\n- Edge cases"))
        #expect(session.documents[.requirements]?.hasPrefix("# Requirements\n\n## 1. Waitlist\n\nP1 · MVP") == true)
        #expect(session.summary(.requirements).criteria == 1)

        await session.approve(.requirements)
        await session.approve(.architecture)
        #expect(session.summary(.tasks).uncoveredCriteria.isEmpty)
        await session.approve(.tasks)

        // Analyze: no tools, a reply in a JSON fence, passed → hand off.
        #expect(script.requests[5].allowsTools == false)
        #expect(session.spec.analyze == .passed)
        #expect(session.spec.analysis?.coverage.first?.id == "1.1")
        #expect(try #require(session.spec.analysis?.analyzedAt).timeIntervalSinceNow > -60)
        session.handOffAnyway()
        #expect(session.spec.stage == .done)

        let agents = project.folder.appending(path: "AGENTS.md")
        #expect(!FileManager.default.fileExists(atPath: agents.path))
        try await session.finish(commitToGit: false, writeAgentsFile: true)
        #expect(try text(session, "prompts/task-01.md").contains("Waitlist store"))
        #expect(try String(contentsOf: project.folder.appending(path: "AGENTS.md"), encoding: .utf8).contains("## Spec: Waitlist"))
        #expect(session.decisions.map(\.title) == ["Should the schedule work offline?"])
        try await expectOnDisk(session)
        #expect(script.requests.count == 6)
    }

    @Test func productWithStopRoundTwoAnalyzeFixAndRefine() async throws {
        let (app, script) = makeApp([
            ("e2e/v2/pr-intake.jsonl", []),
            ("e2e/v2/pr-product.jsonl", []),
            ("e2e/v2/pr-requirements-partial.jsonl", ["hang"]),
            ("e2e/v2/pr-requirements-rest.jsonl", []),
            ("e2e/v2/pr-requirements-revised.jsonl", []),
            ("e2e/v2/pr-experience.jsonl", []),
            ("e2e/v2/pr-architecture.jsonl", []),
            ("e2e/v2/pr-tasks.jsonl", []),
            ("e2e/v2/pr-analyze-issues.jsonl", []),
            ("e2e/v2/pr-tasks-fixed.jsonl", []),
            ("e2e/v2/pr-analyze-passed.jsonl", []),
            ("e2e/v2/pr-impact.jsonl", []),
            ("e2e/v2/pr-experience-refined.jsonl", []),
            ("e2e/v2/pr-architecture-refined.jsonl", []),
            ("e2e/v2/pr-tasks-refined.jsonl", []),
            ("e2e/v2/pr-analyze-passed.jsonl", []),
        ])
        let session = try newSpec(app)

        // Intake, both answers, PRODUCT.md.
        await session.start()
        await session.answer(.option(0, note: nil))
        await session.answer(.option(0, note: nil))
        #expect(session.spec.stage == .review(.product))
        #expect(session.documents[.product] == "# Product\n\n## Problem\n\nMembers can't book yoga classes online.\n\n## Users and roles\n\nMembers and studio staff.\n")
        #expect(session.spec.sessionID == "e2e00000-0000-4000-8000-000000000009")
        #expect(!script.claudeArguments[1].contains("--no-session-persistence"))

        // REQUIREMENTS.md hangs mid-section; Stop interrupts the real process.
        let approving = Task { await session.approve(.product) }
        try await wait("the partial draft") { !session.activity.isEmpty }
        #expect(app.runningSpecID == session.spec.id)
        await session.stop()
        await approving.value
        #expect(session.spec.stage == .stopped(.requirements, .user))
        #expect(app.runningSpecID == nil)
        await session.flush()
        #expect(try text(session, "REQUIREMENTS.md").hasSuffix("## 2. Buy a pack\n\nP1 · MVP\nAs a mem"))

        // Resume in the same Claude Code session; the draft ends with a round-2 question.
        await session.resume()
        #expect(script.claudeArguments[3].contains("--resume"))
        #expect(script.requests[3].resumeSessionID == "e2e00000-0000-4000-8000-000000000010")
        #expect(!script.requests[3].prompt.contains("MVP\nAs a mem"))
        #expect(session.spec.stage == .review(.requirements))
        #expect(session.documents[.requirements]?.components(separatedBy: "## 2. Buy a pack").count == 2)
        #expect(session.summary(.requirements).assumptions == 1)
        let waitlist = try #require(session.followUpQuestions(for: .requirements).first)
        #expect(waitlist.title == "Should full classes have a waitlist?")

        // Round 2: the answer revises REQUIREMENTS.md.
        await session.answerFollowUp(questionID: waitlist.id, .option(0, note: nil))
        #expect(script.requests[4].prompt.contains("Answer to “Should full classes have a waitlist?”: Yes"))
        #expect(session.followUpQuestions(for: .requirements).isEmpty)
        #expect(session.summary(.requirements).stories == 3)

        for kind in [DocKind.requirements, .experience, .architecture, .tasks] { await session.approve(kind) }
        #expect(script.requests[5].prompt.contains("### REQUIREMENTS.md"))

        // Analyze finds an issue; Fix revises TASKS.md, then Analyze passes.
        #expect(session.spec.analyze == .issues(1))
        await session.fixIssues()
        #expect(script.requests[9].prompt.contains("Add a task that builds class packs for 2.1."))
        await session.approve(.tasks)
        #expect(session.spec.analyze == .passed)

        // C1: an edit to REQUIREMENTS.md → impact → reason → refine the three later files.
        let edited = try #require(session.documents[.requirements]).replacingOccurrences(of: "reserve a spot", with: "reserve up to two spots")
        session.save(edited, for: .requirements)
        #expect(session.spec.docs[.experience] == .stale)
        try await wait("the impact run") { session.impact != nil }
        #expect(script.requests[11].allowsTools == false)
        #expect(session.impact?.items.map(\.kind) == [.experience, .tasks])
        #expect(session.impact?.title == "Two spots per booking")
        try await session.saveDecision(reason: "Members bring a friend.", for: .requirements)
        #expect(session.decisions.first?.title == "Two spots per booking")
        #expect(session.decisions.first?.affects == ["1.1"])

        await session.refine()
        #expect(script.requests[12].prompt.contains("Reason: Members bring a friend. Update what this affects here: Confirm booking copy."))
        await session.approve(.experience)
        #expect(script.requests[13].prompt.contains("every part that depends on the change"))
        await session.approve(.architecture)
        #expect(script.requests[14].prompt.contains("Task 1 verify"))
        await session.approve(.tasks)
        #expect(session.spec.analyze == .passed)
        #expect(session.spec.size.files.allSatisfy { session.spec.docs[$0] == .approved })
        #expect(session.documents[.tasks]?.contains("Booking store, two spots") == true)

        session.handOffAnyway()
        try await expectOnDisk(session)
        let decisions = try text(session, "DECISIONS.md")
        for title in ["Two spots per booking", "Should full classes have a waitlist?", "How do members pay?"] { #expect(decisions.contains(title)) }
        #expect(try text(session, ".mel/approved/REQUIREMENTS.md") == session.documents[.requirements])
        #expect(script.requests.count == 16)
        #expect(script.requests.allSatisfy { $0.workingDirectory == session.spec.project })
    }

    @Test func oneRunAtATime() async throws {
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
            ("e2e/v2/pr-requirements-revised.jsonl", []),
        ])
        let session = try newSpec(app)
        await session.start()
        await session.draftNow()
        let approving = Task { await session.approve(.product) }
        try await wait("the partial draft") { !session.activity.isEmpty }
        await session.stop()
        await approving.value

        await session.resume()
        #expect(script.requests[3].resumeSessionID != nil)
        #expect(script.requests[4].resumeSessionID == nil)
        #expect(script.requests[4].prompt == script.requests[2].prompt)
        #expect(session.spec.stage == .review(.requirements))
        #expect(session.summary(.requirements).stories == 3)
        #expect(!notifications.contains { $0.contains("stopped") })   // never shown to the user
    }
}
