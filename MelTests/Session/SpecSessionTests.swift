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

    private func makeSession(_ replies: [[AgentEvent]]) throws -> (SpecSession, FakeRunner, AppState) {
        let runner = FakeRunner(replies)
        let app = AppState(adapter: FakeAdapter(), makeRunner: { _ in runner }, defaults: UserDefaults(suiteName: "mel-tests-\(UUID().uuidString)")!)
        app.agent = .ready(executable: URL(filePath: "/usr/bin/true"), version: "test")
        app.notify = { [unowned self] title, _, at in notifications.append((title, at)) }
        app.authorizeNotifications = { [unowned self] in authorizations += 1 }
        let session = try app.createSpec(name: "Yoga Studio", idea: "Members book yoga classes.", parentFolder: parent)
        self.app = app
        return (session, runner, app)
    }

    private let question = #"{"coverage":[{"label":"Problem","state":"covered"},{"label":"Payments","state":"asking"}],"next":{"id":"payments","title":"How do members pay?","why":"Decides checkout.","shapes":"requirements","options":[{"label":"Class packs","note":"From your idea","suggested":true},{"label":"At the desk","note":"No checkout"}]},"done":false}"#
    private let allCovered = #"{"coverage":[{"label":"Problem","state":"covered"},{"label":"Payments","state":"covered"}],"done":true}"#
    private let product: [AgentEvent] = [.session("s1"), .text("# Product\n\n## Problem\n\nPeople "), .text("can't book.\n"), .done(result: "")]

    private func waitForOpenRun(_ runner: FakeRunner) async throws {
        for _ in 0..<400 where !runner.hasOpenRun { try await Task.sleep(for: .milliseconds(5)) }
        #expect(runner.hasOpenRun)
    }

    @Test func ideaToFourApprovedFilesWithStopAndResume() async throws {
        let requirementsStart = "2 stories\n\n# Requirements\n\n## 1. Book a class\n\nAs a member, I want to book.\n\n- 1.1 THE APP SHALL book.\n\n## 2. Cancel\n\nAs a mem"
        let requirementsRest = "## 2. Cancel\n\nAs a member, I want to cancel.\n\n- 2.1 THE APP SHALL cancel.\n\n> [!ASSUMPTION]\n> Free until 2 h before.\n"
        let (session, runner, app) = try makeSession([
            [.done(result: question)],
            [.done(result: allCovered)],
            product,
            [.session("s2"), .step("read specs/PRODUCT.md"), .text(requirementsStart)],
            [.text(requirementsRest), .done(result: "")],
            [.session("s3"), .text("# Experience\n\n## Flow 1 · Book\n\nPick a class.\n"), .done(result: "")],
            [.session("s3b"), .text("# Architecture\n\n## Stack\n\nSwift.\n"), .done(result: "")],
            [.session("s4"), .text("1 tasks\n\n# Tasks\n\n- [ ] 1. Build it\n  - Covers: 1.1, 2.1\n"), .done(result: "")],
        ])

        // Discovery
        await session.start()
        #expect(session.currentQuestion?.id == "payments")
        #expect(session.spec.coverage.count == 2)
        #expect(runner.requests[0].persistSession == false)
        #expect(runner.requests[0].prompt.contains("Members book yoga classes."))

        await session.answer(.option(0, note: "packs of 10"))
        #expect(runner.requests[1].prompt.contains("How do members pay? Class packs (packs of 10)"))

        // Discovery done → PRODUCT.md drafted
        #expect(session.spec.stage == .review(.product))
        #expect(session.documents[.product] == "# Product\n\n## Problem\n\nPeople can't book.\n")
        #expect(session.spec.sessionID == "s1")
        #expect(notifications.map(\.title) == ["PRODUCT.md is ready for review"])
        #expect(runner.requests[2].persistSession)

        // Approve → REQUIREMENTS.md starts; stop it mid-section.
        let approving = Task { await session.approve(.product) }
        try await waitForOpenRun(runner)
        #expect(session.isRunning)
        #expect(app.runningSpecID == session.spec.id)
        await session.stop()
        await approving.value
        #expect(session.spec.stage == .stopped(.requirements, .user))
        #expect(notifications.count == 1)   // the user's own Stop isn't announced
        #expect(session.documents[.requirements]?.hasPrefix("# Requirements\n") == true)
        #expect(session.activity.map(\.text) == ["read specs/PRODUCT.md"])
        #expect(app.runningSpecID == nil)

        // Resume: truncated to the last complete section, continued in the same session.
        await session.resume()
        let resumed = runner.requests[4]
        #expect(resumed.resumeSessionID == "s2")
        #expect(resumed.prompt.contains("## 1. Book a class"))
        #expect(!resumed.prompt.contains("As a mem\n"))
        #expect(session.spec.stage == .review(.requirements))
        let requirements = try #require(session.documents[.requirements])
        #expect(requirements.components(separatedBy: "## 2. Cancel").count == 2)
        #expect(session.summary(.requirements).criteria == 2)

        session.confirmAssumption(index: 0, in: .requirements)
        #expect(session.summary(.requirements).assumptions == 0)
        await session.approve(.requirements)
        #expect(session.spec.stage == .review(.experience))
        #expect(runner.requests[5].prompt.contains("### REQUIREMENTS.md"))

        await session.approve(.experience)
        #expect(session.spec.stage == .review(.architecture))
        #expect(runner.requests[6].prompt.contains("### EXPERIENCE.md"))

        await session.approve(.architecture)
        #expect(session.spec.stage == .review(.tasks))
        #expect(session.documents[.tasks] == "# Tasks\n\n- [ ] 1. Build it\n  - Covers: 1.1, 2.1\n")
        #expect(session.summary(.tasks).uncoveredCriteria.isEmpty)
        #expect(runner.requests[7].prompt.contains("### ARCHITECTURE.md"))

        await session.approve(.tasks)
        #expect(session.spec.stage == .analyze)   // the analyze run is wired in Wave 7
        #expect(session.spec.size.files.allSatisfy { session.spec.docs[$0] == .approved })

        // Everything is on disk, and the sidebar copy is current.
        await session.flush()
        for kind in session.spec.size.files {
            #expect(try String(contentsOf: session.spec.folder.appending(path: kind.fileName), encoding: .utf8) == session.documents[kind])
        }
        #expect(try SpecStore.loadState(in: session.spec.folder).stage == .analyze)
        #expect(app.specs.first?.stage == .analyze)
        #expect(authorizations == 1)
    }

    @Test func unreadableDiscoveryReplyCanBeRetried() async throws {
        let (session, _, _) = try makeSession([[.done(result: "Sure! Let me ask.")], [.done(result: question)]])
        await session.start()
        #expect(session.lastError != nil)
        #expect(session.currentQuestion == nil)
        await session.retry()
        #expect(session.lastError == nil)
        #expect(session.currentQuestion?.id == "payments")
    }

    @Test func openQuestionTakesFreeText() async throws {
        let open = #"{"coverage":[{"label":"Problem","phase":"product","state":"asking"}],"next":{"id":"idea","title":"What do you have in mind?","why":"","shapes":"product","options":[]},"done":false}"#
        let (session, runner, _) = try makeSession([[.done(result: open)], [.done(result: question)]])
        await session.start()
        #expect(session.currentQuestion?.options == [])
        #expect(session.spec.coverage.first?.phase == .product)
        await session.answer(.text("Calm, for small studios."))
        #expect(runner.requests[1].prompt.contains("- What do you have in mind? Calm, for small studios."))
        #expect(runner.requests[1].prompt.contains("- Problem (product): asking"))
    }

    @Test func draftNowDecidesTheRest() async throws {
        let (session, runner, _) = try makeSession([[.done(result: question)], product])
        await session.start()
        await session.draftNow()
        #expect(session.answeredQuestions.first?.answer == .agentDecides)
        #expect(session.spec.stage == .review(.product))
        #expect(runner.requests[1].prompt.contains("- How do members pay?\n- Payments"))
    }

    @Test func usageLimitWaitsForTheResetAndNotifies() async throws {
        let resetsAt = Date.now.addingTimeInterval(0.3)
        let (session, runner, _) = try makeSession([
            [.done(result: allCovered)],
            [.session("s1"), .text("# Product\n\n## Problem\n\nPeople can't book.\n\n## Users"), .failed(.usageLimit(resetsAt: resetsAt))],
            [.text("## Users and roles\n\nMembers.\n"), .done(result: "")],
        ])
        await session.start()
        #expect(session.spec.stage == .stopped(.product, .usageLimit(resetsAt: resetsAt)))
        #expect(notifications.map(\.title) == ["Yoga Studio stopped"])

        await session.resume()
        #expect(notifications.map(\.title) == ["Yoga Studio stopped", "Yoga Studio can continue", "PRODUCT.md is ready for review"])
        #expect(notifications[1].at == resetsAt)
        #expect(Date.now >= resetsAt)
        #expect(runner.requests[2].resumeSessionID == "s1")
        #expect(session.documents[.product] == "# Product\n\n## Problem\n\nPeople can't book.\n\n## Users and roles\n\nMembers.\n")
    }

    @Test func lostSessionRedraftsFromTheStart() async throws {
        let (session, runner, _) = try makeSession([
            [.done(result: allCovered)],
            [.session("s1"), .text("# Product\n\n## Problem\n\nPeople"), .failed(.timeout)],
            [.failed(.sessionNotFound)],
            product,
        ])
        await session.start()
        await session.resume()
        #expect(runner.requests[2].resumeSessionID == "s1")
        #expect(runner.requests[3].resumeSessionID == nil)
        #expect(runner.requests[3].prompt.contains("You are writing PRODUCT.md"))
        #expect(session.spec.stage == .review(.product))
    }

    @Test func oneRunAtATime() async throws {
        let (session, runner, app) = try makeSession([[.done(result: question)]])
        app.runningSpecID = UUID()
        await session.start()
        #expect(runner.requests.isEmpty)
        #expect(session.lastError != nil)
    }

    @Test func externalEditWithUnsavedTextIsAConflict() async throws {
        let (session, _, _) = try makeSession([[.done(result: allCovered)], product])
        await session.start()
        await session.flush()
        session.save("# Product\n\nMine\n", for: .product)
        try "# Product\n\nTheirs\n".write(to: session.spec.folder.appending(path: "PRODUCT.md"), atomically: true, encoding: .utf8)
        for _ in 0..<400 where session.conflict == nil { try await Task.sleep(for: .milliseconds(10)) }
        #expect(session.conflict == .product)

        session.resolveConflict(keepMine: false)
        #expect(session.conflict == nil)
        #expect(session.documents[.product] == "# Product\n\nTheirs\n")
    }
}
