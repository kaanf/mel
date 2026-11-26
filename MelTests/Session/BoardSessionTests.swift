import Foundation
import Synchronization
import Testing
import MelAgent
import MelSpec
import MelStorage
@testable import Mel

/// Plays scripted replies, one per run. A reply without `done`/`failed` stays open until `stop()`.
private final class ScriptedRunner: AgentRunning {
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

private struct NoAdapter: AgentAdapter {
    func detect(extraPaths: [String]) async -> AgentStatus { .missing }
    func loginCommand(executable: URL) -> String { "" }
    func arguments(for request: AgentRequest) -> [String] { [] }
    func environment(path: String) -> [String: String] { [:] }
    func parse(line: Substring) -> [AgentEvent] { [] }
}

/// The V2 board, driven through SpecSession with scripted agent replies.
@MainActor
final class BoardSessionTests {
    let parent = FileManager.default.temporaryDirectory.appending(path: "mel-board-\(UUID().uuidString)", directoryHint: .isDirectory)
    private var app: AppState?
    private var notifications: [String] = []

    init() throws { try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true) }

    private func makeSession(_ replies: [[AgentEvent]], size: SpecSize = .feature) throws -> (SpecSession, ScriptedRunner) {
        let runner = ScriptedRunner(replies)
        let app = AppState(adapter: NoAdapter(), makeRunner: { _ in runner }, defaults: UserDefaults(suiteName: "mel-tests-\(UUID().uuidString)")!)
        app.agent = .ready(executable: URL(filePath: "/usr/bin/true"), version: "test")
        app.notify = { [unowned self] title, _, _ in notifications.append(title) }
        app.authorizeNotifications = {}
        let session = try app.createSpec(name: "Yoga Studio", idea: "Members book yoga classes.", size: size, project: nil, parent: parent)
        self.app = app
        return (session, runner)
    }

    // Replies
    private let intake = #"{"coverage":[],"questions":[{"id":"pay","title":"How do members pay?","why":"Shapes checkout.","shapes":"requirements","options":[{"label":"Class packs","suggested":true},{"label":"At the desk"}]},{"id":"phones","title":"Which phones first?","shapes":"architecture","options":[{"label":"iOS"},{"label":"Both"}]}]}"#
    private let noQuestions = #"{"coverage":[],"questions":[]}"#
    private let requirements = """
    # Requirements

    ## 1. Book a class

    P1 · MVP

    As a member, I want to book a class.

    - 1.1 WHEN a member taps Book, THE APP SHALL reserve a spot.

    <!-- MVP line -->

    ## 2. Gift cards

    P2

    As a member, I want to buy a gift card.

    - 2.1 WHEN a member pays, THE APP SHALL email the gift card.

    """
    private let trailer = #"<!-- mel:questions [{"id":"waitlist","title":"Is there a waitlist?","about":"full classes","options":[{"label":"Yes","suggested":true},{"label":"No"}]}] -->"#
    private let openQuestion = "\n> [!OPEN QUESTION]\n> How long is a spot held?\n"
    private let architecture = "# Architecture\n\n## Modules\n\n- Booking: reserves spots.\n- Gifts: sends gift cards.\n"
    private let tasks = "# Tasks\n\n- [ ] 1. Booking store\n  - Priority: P1\n  - Covers: 1.1\n  - Verify: `swift test`\n- [ ] 2. Gift mail\n  - Priority: P2\n  - Covers: 2.1\n"
    private let agree = #"{"issues":[]}"#
    private let disagree = #"{"issues":[{"id":"c1","location":"REQUIREMENTS 1.1 · ARCHITECTURE › Modules","text":"One spot against two.","ids":["1.1"],"actions":[{"label":"One Spot","fix":"Say one spot in ARCHITECTURE.md.","files":["architecture"]},{"label":"Two Spots","fix":"Say two spots in criterion 1.1.","files":["requirements"]}]}]}"#

    private func file(_ text: String, session id: String? = nil) -> [AgentEvent] {
        (id.map { [.session($0)] } ?? []) + [.text(text), .done(result: "")]
    }

    private func change(_ edits: (DocKind, String, String)..., tokens: Int? = nil) -> [AgentEvent] {
        let change = Change(edits: edits.map { Change.Edit(file: $0.0, old: $0.1, new: $0.2) })
        return (tokens.map { [.usage(tokens: $0)] } ?? []) + [.done(result: String(decoding: try! JSONEncoder().encode(change), as: UTF8.self))]
    }

    /// No intake questions → three files → check with no contradictions → ready.
    private func readyFeature(check: String? = nil) async throws -> (SpecSession, ScriptedRunner) {
        let (session, runner) = try makeSession([[.done(result: noQuestions)], file(requirements, session: "s1"), file(architecture), file(tasks), [.done(result: check ?? agree)]])
        await session.start(board: true)
        return (session, runner)
    }

    private func wait(_ condition: () -> Bool) async throws {
        for _ in 0..<400 where !condition() { try await Task.sleep(for: .milliseconds(10)) }
        #expect(condition())
    }

    private func onDisk(_ session: SpecSession, _ name: String) async throws -> String {
        await session.flush()
        return try String(contentsOf: session.spec.folder.appending(path: name), encoding: .utf8)
    }

    // MARK: - Intake, gating, check

    @Test func intakeThenFilesOneAtATimeBetweenAnswers() async throws {
        let (session, runner) = try makeSession([
            [.done(result: intake)],
            [.session("s1"), .text("<!-- mel:step 1 -->\n" + requirements + openQuestion), .text("\n" + trailer), .done(result: "")],
            change((.requirements, "> [!OPEN QUESTION]\n> How long is a spot held?\n", "- 1.2 THE APP SHALL hold a spot for 10 minutes.\n"), (.requirements, "reserve a spot.", "reserve a spot or offer the waitlist.")),
            file(architecture), file(tasks), [.done(result: agree)],
        ])
        await session.start(board: true)
        #expect(session.spec.intakeCard?.text == "How do members pay?")
        #expect(runner.requests.count == 1)
        await session.answerIntake(.option(0, note: nil))
        #expect(session.spec.intakeCard?.id == "phones")
        await session.answerIntake(.text("Android only"))

        // REQUIREMENTS.md is written; ARCHITECTURE.md waits for its two cards.
        #expect(session.spec.stage == .board)
        #expect(runner.requests.count == 2)
        #expect(runner.requests[1].prompt.contains("- Which phones first? Android only"))
        #expect(session.spec.written == [.requirements])
        #expect(session.documents[.requirements] == requirements + openQuestion)
        #expect(session.spec.cards.map(\.text) == ["Is there a waitlist?", "How long is a spot held?"])
        #expect(session.spec.cards[0].location == "REQUIREMENTS.md · about full classes")
        #expect(session.spec.gate?.answers == 2)
        #expect(notifications == ["Mel needs you"])
        #expect(session.decisions.map(\.title) == ["Which phones first?", "How do members pay?"])

        await session.answerCard("requirements-waitlist", .option(0, note: nil))
        #expect(runner.requests.count == 2)   // one card still open
        await session.answerCard("requirements-open-0", .text("10 minutes"))

        // One change run for both answers, then the other files and the check without stopping.
        #expect(runner.requests[2].prompt.contains("- REQUIREMENTS.md asked “Is there a waitlist?”. The answer: Yes\n- REQUIREMENTS.md has the open question “How long is a spot held?”. The answer: 10 minutes Remove its callout."))
        #expect(runner.requests[2].prompt.contains(#"{"edits": [{"file": "requirements", "old": "…", "new": "…"}]}"#))
        #expect(!runner.requests[2].allowsTools)
        #expect(session.documents[.requirements]?.contains("- 1.2 THE APP SHALL hold a spot for 10 minutes.") == true)
        #expect(session.documents[.requirements]?.contains("OPEN QUESTION") == false)
        #expect(runner.requests[3].prompt.contains("offer the waitlist"))   // ARCHITECTURE.md is drafted from the changed file
        #expect(runner.requests.count == 6)
        #expect(runner.requests[5].prompt.contains("Find only contradictions"))
        #expect(session.spec.isReady)
        #expect(session.spec.analysis?.issues.map(\.id) == ["task-1.2"] || session.spec.analysis?.issues.isEmpty == true)
        #expect(session.decisions.first?.title == "How long is a spot held?")
        #expect(try await onDisk(session, "REQUIREMENTS.md") == session.documents[.requirements])
        #expect(try await onDisk(session, ".mel/approved/REQUIREMENTS.md") == session.documents[.requirements])
    }

    @Test func skipAndWriteItNowCostNoExtraRun() async throws {
        let (session, runner) = try makeSession([
            [.done(result: intake)],
            [.text(requirements + openQuestion), .text("\n" + trailer), .done(result: "")],
            file(architecture), file(tasks), [.done(result: agree)],
        ])
        await session.start(board: true)
        await session.skipIntake()
        #expect(runner.requests[1].prompt.contains("- How do members pay? You decide"))
        #expect(session.spec.openCards.count == 2)
        await session.writeNow()
        #expect(runner.requests.count == 5)   // no change run: the guesses stand
        #expect(session.spec.cards.map(\.answerText) == ["Mel guessed: Yes", "Mel decided"])
        #expect(session.documents[.requirements]?.contains("OPEN QUESTION") == true)
        #expect(session.spec.isReady)
        #expect(notifications.last == "Yoga Studio is ready")
    }

    @Test func checkIssuesAreCardsAndAnswersFixThem() async throws {
        let (session, runner) = try await readyFeature(check: disagree)
        #expect(session.spec.cards.map(\.id) == ["issue-c1"])
        #expect(session.spec.cards[0].disagrees)
        #expect(!session.spec.isReady)
        #expect(session.spec.analysis?.coverage.first?.architecture == .conflict)

        runner.add([change((.architecture, "reserves spots", "reserves one spot per booking"))])
        await session.answerCard("issue-c1", .option(0, note: nil))
        #expect(runner.requests[5].prompt.contains("- Say one spot in ARCHITECTURE.md."))
        #expect(session.documents[.architecture]?.contains("one spot per booking") == true)
        #expect(runner.requests.count == 6)   // no second check on its own
        #expect(session.spec.isReady)
        #expect(session.decisions.first?.source == "You settled a conflict")

        runner.add([[.done(result: agree)]])
        await session.checkAgain()
        #expect(runner.requests.count == 7)
        #expect(session.spec.cards.isEmpty)

        try await session.startBuilding(commitToGit: false, writeAgentsFile: false)
        #expect(session.spec.stage == .done)
        #expect(try await onDisk(session, "prompts/task-01.md").contains("Booking store"))
    }

    // MARK: - Tell Mel

    @Test func tellMelPatchesFilesLogsTheWordsAndUndoes() async throws {
        let (session, runner) = try await readyFeature()
        runner.add([change((.requirements, "reserve a spot.", "reserve a spot and send a push."), (.tasks, "1. Booking store", "1. Booking store and push"), tokens: 1_800)])
        let sent = await session.tell("  Send a push when a spot is reserved. ")
        #expect(sent)
        #expect(runner.requests[5].prompt.contains("## Requests\n\n- Send a push when a spot is reserved.\n"))
        #expect(runner.requests[5].prompt.contains("### TASKS.md"))
        #expect(session.lastChange?.line == "Changed 1 place in REQUIREMENTS.md, 1 in TASKS.md")
        #expect(session.lastChange?.tokens == 1_800)
        #expect(session.lastChange?.passages[.tasks] == ["1. Booking store and push"])
        #expect(session.decisions.first?.source == "Tell Mel")
        #expect(session.decisions.first?.reason == "Send a push when a spot is reserved.")
        #expect(session.spec.tokens?[.changes] == 1_800)
        #expect(try await onDisk(session, "TASKS.md").contains("Booking store and push"))

        session.undoChange()
        #expect(session.documents[.requirements] == requirements)
        #expect(session.documents[.tasks] == tasks)
        #expect(session.lastChange == nil)
        #expect(session.decisions.first?.source != "Tell Mel")
        #expect(try await onDisk(session, "TASKS.md") == tasks)
        #expect(try await onDisk(session, "DECISIONS.md").contains("Send a push") == false)
    }

    @Test func unplacedChangeChangesNothingUntilRewriteOrCancel() async throws {
        let (session, runner) = try await readyFeature()
        runner.add([
            change((.requirements, "reserve a spot.", "reserve a spot, also offline."), (.architecture, "- Sync: no such line\n", "- Sync: queues bookings.\n")),
            file(architecture + "- Sync: queues bookings.\n"),
        ])
        let sent = await session.tell("Members can book offline.")
        #expect(sent)
        #expect(session.spec.unplacedChange?.files == [.architecture])
        #expect(session.documents[.requirements] == requirements)   // nothing changed, not even the edit that fit
        #expect(session.lastChange == nil)
        #expect(!session.spec.isReady)

        await session.rewriteUnplaced()
        #expect(runner.requests[6].prompt.contains("your reply is the whole new file"))
        #expect(runner.requests[6].prompt.contains("Members can book offline."))
        #expect(session.spec.unplacedChange == nil)
        #expect(session.documents[.architecture]?.hasSuffix("- Sync: queues bookings.\n") == true)
        #expect(session.documents[.requirements]?.contains("also offline") == true)
        #expect(session.lastChange?.line == "Rewrote ARCHITECTURE.md")
        #expect(session.decisions.first?.source == "You chose a full rewrite")
        #expect(session.spec.isReady)

        runner.add([change((.tasks, "no such text", "x"))])
        _ = await session.tell("Add a sync task.")
        let back = await session.cancelUnplaced()
        #expect(back == "Add a sync task.")
        #expect(session.spec.unplacedChange == nil)
        #expect(session.documents[.tasks] == tasks)
    }

    @Test func stoppedOrUnreadableTellKeepsTheRequest() async throws {
        let (session, runner) = try await readyFeature()
        runner.add([[.done(result: "I changed it.")], [.failed(.timeout)]])
        let unreadable = await session.tell("Add reminders.")
        #expect(!unreadable)
        #expect(session.lastError != nil)
        #expect(session.spec.halted == nil)
        let stopped = await session.tell("Add reminders.")
        #expect(!stopped)
        #expect(session.documents[.requirements] == requirements)
        #expect(session.spec.isReady)
    }

    // MARK: - Plan: scope and removal

    @Test func scopeMovesAreFreeAndRecheckCoverage() async throws {
        let (session, runner) = try await readyFeature()
        #expect(session.stories.map(\.isFirst) == [true, false])
        session.moveStory("2", toLater: false)
        #expect(runner.requests.count == 5)   // no run
        #expect(session.stories.map(\.isFirst) == [true, true])
        #expect(session.documents[.requirements]?.contains("## 2. Gift cards\n\nP1 · MVP") == true)
        #expect(session.spec.analysis?.stats.first?.value == "2 of 2")
        #expect(try await onDisk(session, "REQUIREMENTS.md") == session.documents[.requirements])
        session.moveStory("2", toLater: true)
        #expect(session.documents[.requirements] == requirements)
    }

    @Test func removeCutsTheStoryAndRestorePutsItBack() async throws {
        let (session, runner) = try await readyFeature()
        #expect(session.removal(ofStory: "2")?.summary == "Also removes requirement 2.1 and task 2.")
        runner.add([change((.architecture, "- Gifts: sends gift cards.\n", ""), (.tasks, "- [ ] 2. Gift mail\n  - Priority: P2\n  - Covers: 2.1\n", ""))])
        await session.removeStory("2")
        #expect(runner.requests[5].prompt.contains("Story 2 “Gift cards” was removed from REQUIREMENTS.md, with criterion 2.1. Remove task 2."))
        #expect(runner.requests[5].prompt.contains("## 2. Gift cards") == false)   // already cut by Mel
        #expect(session.stories.map(\.id) == ["1"])
        #expect(session.documents[.tasks]?.contains("Gift") == false)
        #expect(session.documents[.architecture]?.contains("Gifts") == false)
        #expect(session.lastChange?.line == "Removed “Gift cards”")
        #expect(session.decisions.first?.title == "Removed: Gift cards")
        #expect(session.spec.removedStories?.map(\.title) == ["Gift cards"])
        #expect(session.spec.isReady)

        runner.add([change((.requirements, "<!-- MVP line -->\n", "<!-- MVP line -->\n\n## 2. Gift cards\n\nP2\n\nAs a member, I want to buy a gift card.\n\n- 2.1 WHEN a member pays, THE APP SHALL email the gift card.\n"))])
        await session.restoreStory("2")
        #expect(runner.requests[6].prompt.contains("Put story 2 “Gift cards” back into REQUIREMENTS.md"))
        #expect(runner.requests[6].prompt.contains("- 2.1 WHEN a member pays, THE APP SHALL email the gift card."))
        #expect(session.stories.map(\.id) == ["1", "2"])
        #expect(session.spec.removedStories?.isEmpty == true)
        #expect(session.decisions.first?.title == "Restored: Gift cards")
    }

    @Test func failedRemovalPutsTheStoryBack() async throws {
        let (session, runner) = try await readyFeature()
        runner.add([change((.tasks, "no such task", ""))])
        await session.removeStory("2")
        #expect(session.documents[.requirements] == requirements)
        #expect(session.spec.unplacedChange == nil)
        #expect(session.lastError?.contains("Gift cards") == true)
        #expect(try await onDisk(session, "REQUIREMENTS.md") == requirements)
    }

    // MARK: - Edits by hand

    @Test func editWaitsForUpdateKeepOrUndo() async throws {
        let (session, runner) = try await readyFeature()
        let edited = requirements.replacingOccurrences(of: "reserve a spot.", with: "reserve up to two spots.")
        session.save(edited, for: .requirements)
        #expect(session.spec.builtOnEdit == [.architecture, .tasks])
        #expect(!session.spec.isReady)
        try await Task.sleep(for: .milliseconds(700))
        #expect(runner.requests.count == 5)   // no impact run on the board

        runner.add([change((.architecture, "reserves spots", "reserves up to two spots"))])
        await session.updateAfterEdit(why: "Members bring a friend.")
        let prompt = runner.requests[5].prompt
        #expect(prompt.contains("The user edited REQUIREMENTS.md by hand. Lines removed:\n- 1.1 WHEN a member taps Book, THE APP SHALL reserve a spot.\nLines added:\n- 1.1 WHEN a member taps Book, THE APP SHALL reserve up to two spots."))
        #expect(prompt.contains("leave REQUIREMENTS.md as it is. Why: Members bring a friend."))
        #expect(session.documents[.architecture]?.contains("up to two spots") == true)
        #expect(session.spec.builtOnEdit.isEmpty)
        #expect(session.spec.isReady)
        #expect(session.decisions.first?.reason == "Members bring a friend.")
        #expect(session.snapshots[.requirements] == edited)

        session.save(requirements, for: .requirements)
        await session.undoBoardEdit()
        #expect(session.documents[.requirements] == edited)
        session.save(requirements, for: .requirements)
        await session.keepEdit(why: "")
        #expect(session.documents[.requirements] == requirements)
        #expect(session.spec.isReady)
        #expect(runner.requests.count == 6)
    }

    // MARK: - Stops

    @Test func stoppedDraftResumesInItsSessionAndFinishedFilesStay() async throws {
        let (session, runner) = try makeSession([
            [.done(result: noQuestions)],
            file(requirements, session: "s1"),
            [.session("s2"), .text("# Architecture\n\n## Modules\n\n- Booking: reserves spots.\n\n## Data\n\nBook"), .failed(.usageLimit(resetsAt: nil))],
            [.text("## Data\n\nBookings.\n"), .done(result: "")],
            file(tasks), [.done(result: agree)],
        ])
        await session.start(board: true)
        #expect(session.spec.halted == Halt(reason: .usageLimit(resetsAt: nil), file: .architecture))
        #expect(session.spec.fileState(.architecture) == .needsYou)
        #expect(session.spec.fileState(.requirements) == .ready)
        #expect(notifications == ["Yoga Studio stopped"])
        #expect(runner.requests.count == 3)

        await session.resumeBoard()
        #expect(runner.requests[3].resumeSessionID == "s2")
        #expect(runner.requests[3].prompt.contains("## Modules"))
        #expect(!runner.requests[3].prompt.contains("Book\n"))
        #expect(session.documents[.architecture] == "# Architecture\n\n## Modules\n\n- Booking: reserves spots.\n\n## Data\n\nBookings.\n")
        #expect(session.spec.isReady)
    }

    @Test func userStopHaltsAndUnreadableAnswersHalt() async throws {
        let (session, runner) = try makeSession([[.done(result: noQuestions)], [.text(requirements), .text("\n" + trailer), .done(result: "")], [], [.done(result: "Done!")], change()])
        await session.start(board: true)
        let answering = Task { await session.answerCard("requirements-waitlist", .option(1, note: nil)) }
        try await wait { runner.hasOpenRun }
        await session.stop()
        await answering.value
        #expect(session.spec.halted == Halt(reason: .user))
        #expect(session.spec.changeRequests.count == 1)   // the answer still waits

        await session.resumeBoard()
        #expect(session.spec.halted?.reason == .crashed("Claude Code's reply couldn't be read."))
        #expect(runner.requests.count == 4)   // no retry loop
        runner.add([file(architecture), file(tasks), [.done(result: agree)]])
        await session.resumeBoard()
        #expect(session.spec.changeRequests.isEmpty)
        #expect(session.spec.isReady)
    }

    @Test func quickFixIsOneFileAndNoCheck() async throws {
        let (session, runner) = try makeSession([[.done(result: noQuestions)], file("# Fix\n\n## What breaks\n\nIt crashes.\n")], size: .quickFix)
        await session.start(board: true)
        #expect(runner.requests.count == 2)
        #expect(session.spec.isReady)
        try await session.startBuilding(commitToGit: false, writeAgentsFile: false)
        #expect(session.spec.stage == .done)
    }
}
