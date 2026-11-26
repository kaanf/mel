import Foundation
import Synchronization
import Testing
import MelAgent
import MelSpec
import MelStorage
@testable import Mel

/// Plays scripted replies, one per run. A reply without `done`/`failed` stays open until `stop()`.
private final class FakeRunner: AgentRunning {
    private struct State {
        var replies: [[AgentEvent]]
        var requests: [AgentRequest] = []
        var open: AsyncThrowingStream<AgentEvent, Error>.Continuation?
    }
    private let state: Mutex<State>

    init(_ replies: [[AgentEvent]]) { state = Mutex(State(replies: replies)) }

    var requests: [AgentRequest] { state.withLock { $0.requests } }
    var hasOpenRun: Bool { state.withLock { $0.open != nil } }

    func add(_ replies: [[AgentEvent]]) { state.withLock { $0.replies += replies } }

    func run(_ request: AgentRequest) -> AsyncThrowingStream<AgentEvent, Error> {
        AsyncThrowingStream { continuation in
            let events = state.withLock { s in
                s.requests.append(request)
                return s.replies.isEmpty ? [] : s.replies.removeFirst()
            }
            for event in events { continuation.yield(event) }
            switch events.last {
            case .done, .failed: continuation.finish()
            default: state.withLock { $0.open = continuation }
            }
        }
    }

    func stop() async {
        let open = state.withLock { s in defer { s.open = nil }; return s.open }
        open?.yield(.failed(.user))
        open?.finish()
    }
}

private struct FakeAdapter: AgentAdapter {
    func detect(extraPaths: [String]) async -> AgentStatus { .missing }
    func loginCommand(executable: URL) -> String { "" }
    func arguments(for request: AgentRequest) -> [String] { [] }
    func environment(path: String) -> [String: String] { [:] }
    func parse(line: Substring) -> [AgentEvent] { [] }
}

@MainActor
final class SpecSessionTests {
    let parent = FileManager.default.temporaryDirectory.appending(path: "mel-session-\(UUID().uuidString)", directoryHint: .isDirectory)
    /// Sessions hold their AppState weakly; the test keeps it alive like MelApp does.
    private var app: AppState?
    private var notifications: [(title: String, at: Date?)] = []
    private var authorizations = 0

    init() throws { try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true) }

    private func makeSession(_ replies: [[AgentEvent]], size: SpecSize = .feature) throws -> (SpecSession, FakeRunner, AppState) {
        let runner = FakeRunner(replies)
        let app = AppState(adapter: FakeAdapter(), makeRunner: { _ in runner }, defaults: UserDefaults(suiteName: "mel-tests-\(UUID().uuidString)")!)
        app.agent = .ready(executable: URL(filePath: "/usr/bin/true"), version: "test")
        app.notify = { [unowned self] title, _, at in notifications.append((title, at)) }
        app.authorizeNotifications = { [unowned self] in authorizations += 1 }
        let session = try app.createSpec(name: "Yoga Studio", idea: "Members book yoga classes.", size: size, project: nil, parent: parent)
        self.app = app
        return (session, runner, app)
    }

    // Replies
    private let intake = #"{"coverage":[{"label":"Goal","state":"covered"},{"label":"Edge cases","state":"notYet"}],"questions":[{"id":"payments","title":"How do members pay?","why":"Shapes checkout.","shapes":"requirements","options":[{"label":"Class packs","suggested":true},{"label":"At the desk"}]},{"id":"offline","title":"Should the schedule work offline?","shapes":"architecture","options":[{"label":"Yes"},{"label":"No"}]}]}"#
    private let noQuestions = #"{"coverage":[{"label":"Goal","state":"covered"}],"questions":[]}"#
    private let trailer = #"<!-- mel:questions [{"id":"waitlist","title":"Is there a waitlist?","why":"Full classes.","options":[{"label":"Yes"},{"label":"No"}]}] -->"#
    private let requirements = "# Requirements\n\n## 1. Book a class\n\nAs a member, I want to book.\n\n- 1.1 THE APP SHALL book.\n"
    private let architecture = "# Architecture\n\n## Modules\n\n- Booking\n"
    private let tasks = "# Tasks\n\n- [ ] 1. Build booking\n  - Covers: 1.1\n"
    private let passed = #"{"stats":[],"issues":[],"coverage":[]}"#
    private let issues = #"{"stats":[],"issues":[{"id":"i1","kind":"noTask","location":"REQUIREMENTS 1.1","text":"No test.","actions":[{"label":"Add Task","fix":"Add a test task for 1.1.","files":["tasks"]}]}],"coverage":[]}"#
    private let untitledImpact = #"{"items":[{"kind":"tasks","what":"Task 1","count":"1 task"}]}"#
    private let impact = #"{"title":"Refunds","items":[{"kind":"architecture","what":"the Booking module","count":"1 section"},{"kind":"tasks","what":"Task 1","count":"1 task"}]}"#

    private func file(_ text: String, session id: String? = nil) -> [AgentEvent] {
        (id.map { [.session($0)] } ?? []) + [.text(text), .done(result: "")]
    }

    /// A revise reply: a patch that adds `text` after `line`.
    private func adding(_ text: String, after line: String) -> [AgentEvent] {
        let patch = Patch(edits: [Patch.Edit(old: line, new: line + text)])
        return [.done(result: String(decoding: try! JSONEncoder().encode(patch), as: UTF8.self))]
    }

    /// Intake with no questions → three files → Analyze passed. Ends in `.analyze`.
    private func approvedFeature(analyze: String? = nil) throws -> (SpecSession, FakeRunner, AppState) {
        try makeSession([[.done(result: noQuestions)], file(requirements, session: "s1"), file(architecture), file(tasks), [.done(result: analyze ?? passed)]])
    }

    private func approveAll(_ session: SpecSession) async {
        for kind in session.spec.size.files { await session.approve(kind) }
    }

    private func wait(_ condition: () -> Bool) async throws {
        for _ in 0..<400 where !condition() { try await Task.sleep(for: .milliseconds(10)) }
        #expect(condition())
    }

    // MARK: - Intake and drafting

    @Test func intakeAnswersDraftRoundTwoAndHandOff() async throws {
        let (session, runner, app) = try makeSession([
            [.done(result: intake)],
            [.session("s1"), .step("read README.md"), .text("<!-- mel:step 1 -->\n" + requirements), .text("\n" + trailer), .done(result: "")],
            adding("- 1.2 THE APP SHALL keep a waitlist.\n", after: "- 1.1 THE APP SHALL book.\n"),
            file(architecture), file(tasks), [.done(result: passed)],
        ])

        // Intake: one run returns every question.
        await session.start()
        #expect(session.currentQuestion?.id == "payments")
        #expect(session.spec.questions.count == 2)
        #expect(session.spec.coverage.map(\.label) == ["Goal", "Edge cases"])
        #expect(runner.requests[0].persistSession == false)
        #expect(runner.requests[0].prompt.contains("Members book yoga classes."))

        await session.answer(.option(0, note: "packs of 10"))
        #expect(session.currentQuestion?.id == "offline")
        #expect(runner.requests.count == 1)
        await session.answer(.option(1, note: nil))

        // All answered → REQUIREMENTS.md, without markers and trailer, with a round-2 question.
        #expect(session.spec.stage == .review(.requirements))
        #expect(runner.requests[1].persistSession)
        #expect(runner.requests[1].prompt.contains("- How do members pay? Class packs (packs of 10)"))
        #expect(session.documents[.requirements] == requirements)
        #expect(session.activity.map(\.text) == ["read README.md"])
        #expect(session.spec.sessionID == "s1")
        #expect(session.followUpQuestions(for: .requirements).map(\.id) == ["requirements-waitlist"])
        #expect(session.decisions.map(\.title) == ["Should the schedule work offline?", "How do members pay?"])
        #expect(notifications.map(\.title) == ["REQUIREMENTS.md is ready for review"])

        // Round 2 → revise with the answer.
        await session.answerFollowUp(questionID: "requirements-waitlist", .option(0, note: nil))
        #expect(runner.requests[2].prompt.contains("Answer to “Is there a waitlist?”: Yes"))
        #expect(runner.requests[2].prompt.contains("## 1. Book a class"))
        #expect(runner.requests[2].prompt.contains(#"{"edits": [{"old": "…", "new": "…"}]}"#))
        #expect(!runner.requests[2].allowsTools)
        #expect(!runner.requests[2].persistSession)
        #expect(session.documents[.requirements] == requirements + "- 1.2 THE APP SHALL keep a waitlist.\n")
        #expect(session.spec.stage == .review(.requirements))
        #expect(session.followUpQuestions(for: .requirements).isEmpty)
        #expect(session.summary(.requirements).criteria == 2)

        // Approve each file; the next one is drafted with the approved text.
        await session.approve(.requirements)
        #expect(session.snapshots[.requirements] == session.documents[.requirements])
        #expect(session.spec.stage == .review(.architecture))
        #expect(runner.requests[3].prompt.contains("### REQUIREMENTS.md"))
        await session.approve(.architecture)
        #expect(runner.requests[4].prompt.contains("### ARCHITECTURE.md"))
        await session.approve(.tasks)

        // Analyze runs without tools.
        #expect(runner.requests[5].allowsTools == false)
        #expect(session.spec.stage == .analyze)
        // Mel's own check: the criterion round 2 added has no task. The agent found no contradiction.
        #expect(session.spec.analysis?.issues.map(\.id) == ["task-1.2"])
        #expect(session.spec.analysis?.stats.map(\.value) == ["1 of 2", "0"])
        #expect(session.spec.analyze == .issues(1))
        session.handOffAnyway()
        #expect(session.spec.stage == .done)

        // Task prompts, then everything is on disk and the sidebar copy is current.
        let prompts = try await session.writeTaskPrompts()
        #expect(prompts.map(\.lastPathComponent) == ["task-01.md"])
        #expect(session.startCommand.contains("specs/yoga-studio/prompts/task-01.md"))
        await session.flush()
        for kind in session.spec.size.files {
            #expect(try String(contentsOf: session.spec.folder.appending(path: kind.fileName), encoding: .utf8) == session.documents[kind])
            #expect(try String(contentsOf: session.spec.folder.appending(path: ".mel/approved/\(kind.fileName)"), encoding: .utf8) == session.documents[kind])
        }
        #expect(try SpecStore.loadState(in: session.spec.folder).stage == .done)
        #expect(try String(contentsOf: session.spec.folder.appending(path: "DECISIONS.md"), encoding: .utf8).contains("How do members pay?"))
        #expect(app.specs.first?.stage == .done)
        #expect(authorizations == 1)
    }

    @Test func draftNowLeavesTheRestToClaude() async throws {
        let (session, runner, _) = try makeSession([[.done(result: intake)], file(requirements)])
        await session.start()
        await session.answer(.option(0, note: nil))
        await session.draftNow()
        #expect(session.answeredQuestions.last?.answer == .agentDecides)
        #expect(session.spec.stage == .review(.requirements))
        #expect(runner.requests[1].prompt.contains("- Should the schedule work offline?\n- Edge cases"))
        #expect(session.decisions.map(\.title) == ["How do members pay?"])
    }

    @Test func unreadableIntakeCanBeRetried() async throws {
        let (session, _, _) = try makeSession([[.done(result: "Sure! Let me ask.")], [.done(result: intake)]])
        await session.start()
        #expect(session.lastError != nil)
        #expect(session.currentQuestion == nil)
        await session.retry()
        #expect(session.lastError == nil)
        #expect(session.currentQuestion?.id == "payments")
    }

    @Test func quickFixIsDoneAfterApproval() async throws {
        let (session, runner, _) = try makeSession([[.done(result: noQuestions)], file("# Fix\n\n## What breaks\n\nIt crashes.\n")], size: .quickFix)
        await session.start()
        #expect(session.spec.stage == .review(.spec))
        await session.approve(.spec)
        #expect(session.spec.stage == .done)
        #expect(runner.requests.count == 2)
        #expect(session.startCommand.contains("SPEC.md"))
    }

    // MARK: - Recovery

    @Test func stopThenResumeContinuesTheSession() async throws {
        let (session, runner, app) = try makeSession([
            [.done(result: noQuestions)],
            [.session("s1"), .text("# Requirements\n\n## 1. Book a class\n\nAs a member, I want to book.\n\n## 2. Cancel\n\nAs a mem")],
            [.text("## 2. Cancel\n\nAs a member, I want to cancel.\n"), .done(result: "")],
        ])
        let starting = Task { await session.start() }
        try await wait { runner.hasOpenRun }
        #expect(session.isRunning)
        #expect(app.runningSpecID == session.spec.id)
        await session.stop()
        await starting.value
        #expect(session.spec.stage == .stopped(.requirements, .user))
        #expect(notifications.isEmpty)   // the user's own Stop isn't announced
        #expect(app.runningSpecID == nil)

        await session.resume()
        #expect(runner.requests[2].resumeSessionID == "s1")
        #expect(runner.requests[2].prompt.contains("## 1. Book a class"))
        #expect(!runner.requests[2].prompt.contains("As a mem\n"))
        #expect(session.spec.stage == .review(.requirements))
        #expect(session.documents[.requirements]?.components(separatedBy: "## 2. Cancel").count == 2)
    }

    @Test func usageLimitWaitsForTheResetAndNotifies() async throws {
        let resetsAt = Date.now.addingTimeInterval(0.3)
        let (session, runner, _) = try makeSession([
            [.done(result: noQuestions)],
            [.session("s1"), .text("# Requirements\n\n## 1. Book\n\nBook.\n\n## 2. Can"), .failed(.usageLimit(resetsAt: resetsAt))],
            [.text("## 2. Cancel\n\nCancel.\n"), .done(result: "")],
        ])
        await session.start()
        #expect(session.spec.stage == .stopped(.requirements, .usageLimit(resetsAt: resetsAt)))
        #expect(notifications.map(\.title) == ["Yoga Studio stopped"])

        await session.resume()
        #expect(notifications.map(\.title) == ["Yoga Studio stopped", "Yoga Studio can continue", "REQUIREMENTS.md is ready for review"])
        #expect(notifications[1].at == resetsAt)
        #expect(Date.now >= resetsAt)
        #expect(runner.requests[2].resumeSessionID == "s1")
        #expect(session.documents[.requirements] == "# Requirements\n\n## 1. Book\n\nBook.\n\n## 2. Cancel\n\nCancel.\n")
    }

    @Test func lostSessionRedraftsFromTheStart() async throws {
        let (session, runner, _) = try makeSession([
            [.done(result: noQuestions)],
            [.session("s1"), .text("# Requirements\n\n## 1. Book"), .failed(.timeout)],
            [.failed(.sessionNotFound)],
            file(requirements),
        ])
        await session.start()
        await session.resume()
        #expect(runner.requests[2].resumeSessionID == "s1")
        #expect(runner.requests[3].resumeSessionID == nil)
        #expect(runner.requests[3].prompt == runner.requests[1].prompt)
        #expect(session.spec.stage == .review(.requirements))
        #expect(notifications.map(\.title) == ["Yoga Studio stopped", "REQUIREMENTS.md is ready for review"])
    }

    @Test func oneRunAtATime() async throws {
        let (session, runner, app) = try makeSession([[.done(result: intake)]])
        app.runningSpecID = UUID()
        await session.start()
        #expect(runner.requests.isEmpty)
        #expect(session.lastError != nil)
    }

    // MARK: - Analyze

    @Test func fixIssuesRevisesThenAnalyzesAgain() async throws {
        let (session, runner, _) = try approvedFeature(analyze: issues)
        runner.add([adding("- [ ] 2. Test booking\n  - Covers: 1.1\n", after: "  - Covers: 1.1\n"), [.done(result: passed)]])
        await session.start()
        await approveAll(session)
        #expect(session.spec.analyze == .issues(1))

        await session.fixIssues()
        #expect(runner.requests[5].prompt.contains("Add a test task for 1.1."))
        #expect(session.spec.stage == .review(.tasks))
        await session.approve(.tasks)
        #expect(session.spec.stage == .analyze)
        #expect(session.spec.analyze == .passed)
        #expect(session.tasks.count == 2)
    }

    @Test func unplacedPatchChangesNothingAndCancelDropsIt() async throws {
        let (session, runner, _) = try approvedFeature(analyze: issues)
        runner.add([adding("- [ ] 2. Test booking\n", after: "- [ ] 9. No such task\n")])
        await session.start()
        await approveAll(session)
        notifications = []

        await session.fixIssues()
        #expect(session.spec.stage == .review(.tasks))
        #expect(session.spec.unplaced == [.tasks])
        #expect(session.documents[.tasks] == tasks)
        #expect(notifications.isEmpty)

        session.cancelRewrite(.tasks)
        #expect(session.spec.unplaced.isEmpty)
        #expect(session.spec.instructions.isEmpty)
        #expect(runner.requests.count == 6)
    }

    @Test func rewriteAfterAnUnreadablePatchWritesTheWholeFile() async throws {
        let (session, runner, _) = try approvedFeature(analyze: issues)
        runner.add([[.done(result: "I added the task.")], file(tasks + "- [ ] 2. Test booking\n  - Covers: 1.1\n"), [.done(result: passed)]])
        await session.start()
        await approveAll(session)
        await session.fixIssues()
        #expect(session.spec.unplaced == [.tasks])

        await session.rewrite(.tasks)
        #expect(runner.requests[6].prompt.contains("your reply is the whole new file"))
        #expect(runner.requests[6].prompt.contains("Add a test task for 1.1."))
        #expect(runner.requests[6].allowsTools)
        #expect(session.spec.stage == .review(.tasks))
        #expect(session.spec.unplaced.isEmpty)
        #expect(session.spec.rewriting == nil)
        #expect(session.tasks.count == 2)
        await session.approve(.tasks)
        #expect(session.spec.analyze == .passed)
    }

    @Test func stoppedPatchKeepsTheFileAndResumeRunsItAgain() async throws {
        let (session, runner, _) = try approvedFeature(analyze: issues)
        runner.add([[], adding("- [ ] 2. Test booking\n  - Covers: 1.1\n", after: "  - Covers: 1.1\n")])
        await session.start()
        await approveAll(session)
        let fixing = Task { await session.fixIssues() }
        try await wait { runner.hasOpenRun }
        await session.stop()
        await fixing.value
        #expect(session.spec.stage == .stopped(.tasks, .user))
        #expect(session.documents[.tasks] == tasks)

        await session.resume()
        #expect(runner.requests[6].prompt == runner.requests[5].prompt)
        #expect(runner.requests[6].resumeSessionID == nil)
        #expect(session.spec.stage == .review(.tasks))
        #expect(session.tasks.count == 2)
    }

    @Test func tokensAreSummedPerStep() async throws {
        let (session, runner, _) = try makeSession([
            [.usage(tokens: 900), .done(result: noQuestions)],
            [.text(requirements), .usage(tokens: 4_000), .done(result: "")],
            [.text(architecture), .usage(tokens: 3_000), .done(result: "")],
            [.text(tasks), .usage(tokens: 2_000), .done(result: "")],
            [.usage(tokens: 1_500), .done(result: issues)],
            [.usage(tokens: 300), .done(result: "No JSON")],
            [.text(tasks), .usage(tokens: 2_500), .done(result: "")],
            [.usage(tokens: 1_000), .failed(.timeout)],
        ])
        await session.start()
        await approveAll(session)
        await session.fixIssues()
        await session.rewrite(.tasks)
        await session.approve(.tasks)
        #expect(runner.requests.count == 8)
        #expect(session.spec.tokens == [.questions: 900, .requirements: 4_000, .architecture: 3_000, .tasks: 2_000, .checks: 2_500, .changes: 2_800])
        #expect(session.spec.tokenTotal == 15_200)
        await session.flush()
        let state = try String(contentsOf: session.spec.folder.appending(path: ".mel/state.json"), encoding: .utf8)
        #expect(state.contains(#""changes" : 2800"#))
    }

    @Test func unreadableAnalyzeShowsRerun() async throws {
        let (session, runner, _) = try approvedFeature(analyze: "No JSON here.")
        runner.add([[.done(result: passed)]])
        await session.start()
        await approveAll(session)
        #expect(session.spec.analyze == .stale)
        #expect(session.lastError != nil)
        await session.analyze()
        #expect(session.spec.analyze == .passed)
    }

    // MARK: - Refine (C1)

    private func editRequirements(_ session: SpecSession) async throws {
        session.save(requirements + "- 1.2 THE APP SHALL refund.\n", for: .requirements)
        #expect(session.spec.docs[.requirements] == .edited)
        #expect(session.spec.docs[.architecture] == .stale)
        #expect(session.spec.docs[.tasks] == .stale)
        #expect(session.spec.analyze == .stale)
        try await wait { session.impact != nil }
    }

    @Test func editRunsImpactAndUndoRestoresTheSnapshot() async throws {
        let (session, runner, _) = try approvedFeature()
        runner.add([[.done(result: impact)]])
        await session.start()
        await approveAll(session)
        try await editRequirements(session)
        #expect(runner.requests[5].allowsTools == false)
        #expect(runner.requests[5].prompt.contains("1.2 THE APP SHALL refund."))
        #expect(session.impact?.items.map(\.kind) == [.architecture, .tasks])

        await session.undoEdit(.requirements)
        #expect(session.documents[.requirements] == requirements)
        #expect(session.spec.size.files.allSatisfy { session.spec.docs[$0] == .approved })
        #expect(session.spec.analyze == .passed)
        #expect(session.impact == nil)
    }

    @Test func keepAsIsMakesTheEditApproved() async throws {
        let (session, runner, _) = try approvedFeature()
        runner.add([[.done(result: untitledImpact)]])
        await session.start()
        await approveAll(session)
        try await editRequirements(session)
        try await session.saveDecision(reason: "Studios asked for it.", for: .requirements)
        #expect(session.decisions.first?.title == "Changed \(DocKind.requirements.title)")   // the impact reply had no title
        #expect(session.decisions.first?.affects == ["1.2"])

        session.keepAsIs()
        #expect(session.spec.size.files.allSatisfy { session.spec.docs[$0] == .approved })
        #expect(session.snapshots[.requirements] == session.documents[.requirements])
        #expect(session.impact == nil)
    }

    @Test func refineRevisesEachStaleFile() async throws {
        let (session, runner, _) = try approvedFeature()
        runner.add([[.done(result: impact)], adding("- Refunds\n", after: "- Booking\n"), adding("- [ ] 2. Refunds\n  - Covers: 1.2\n", after: "  - Covers: 1.1\n"), [.done(result: passed)]])
        await session.start()
        await approveAll(session)
        try await editRequirements(session)
        try await session.saveDecision(reason: "Studios asked for it.", for: .requirements)
        #expect(session.decisions.first?.title == "Refunds")

        await session.refine()
        #expect(runner.requests[6].prompt.contains("Reason: Studios asked for it. Update what this affects here: the Booking module."))
        #expect(session.spec.stage == .review(.architecture))
        #expect(session.spec.docs[.requirements] == .approved)
        await session.approve(.architecture)
        #expect(runner.requests[7].prompt.contains("Update what this affects here: Task 1."))
        await session.approve(.tasks)
        #expect(session.spec.analyze == .passed)
        #expect(session.summary(.tasks).uncoveredCriteria.isEmpty)
    }

    // MARK: - Files

    @Test func externalEditWithUnsavedTextIsAConflict() async throws {
        let (session, _, _) = try makeSession([[.done(result: noQuestions)], file(requirements)])
        await session.start()
        await session.flush()
        session.save("# Requirements\n\nMine\n", for: .requirements)
        try "# Requirements\n\nTheirs\n".write(to: session.spec.folder.appending(path: "REQUIREMENTS.md"), atomically: true, encoding: .utf8)
        try await wait { session.conflict != nil }
        #expect(session.conflict == .requirements)

        session.resolveConflict(keepMine: false)
        #expect(session.conflict == nil)
        #expect(session.documents[.requirements] == "# Requirements\n\nTheirs\n")
    }

    @Test func attachmentsAreListedInTheDraftPrompt() async throws {
        let (session, runner, _) = try makeSession([[.done(result: noQuestions)], file(requirements)])
        try await session.attachLog("crash at launch")
        #expect(session.spec.attachments.count == 1)
        await session.start()
        let name = try #require(session.spec.attachments.first?.fileName)
        #expect(runner.requests[0].prompt.contains("specs/yoga-studio/.mel/attachments/\(name)"))
        #expect(runner.requests[1].prompt.contains("specs/yoga-studio/.mel/attachments/\(name)"))
    }
}
