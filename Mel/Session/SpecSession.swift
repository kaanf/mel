import Foundation
import Observation
import MelAgent
import MelSpec
import MelStorage
import MelSystem

@Observable final class SpecSession {
    private(set) var spec: Spec
    private(set) var documents: [DocKind: String]
    private(set) var liveText: String
    private(set) var activity: [ActivityLine]
    private(set) var isRunning: Bool
    private(set) var lastError: String?
    private(set) var conflict: DocKind?

    @ObservationIgnored private weak var app: AppState?
    @ObservationIgnored private let store: SpecStore?
    @ObservationIgnored private var watcher: FileWatcher?
    /// File writes and state saves, in order.
    @ObservationIgnored private var io: Task<Void, Never>?
    /// The text Mel last wrote per file; tells an external edit from unsaved editor text.
    @ObservationIgnored private var saved: [DocKind: String] = [:]
    @ObservationIgnored private var pendingSaves: [DocKind: Task<Void, Never>] = [:]
    @ObservationIgnored private var conflictText = ""

    @ObservationIgnored private var runner: (any AgentRunning)?
    @ObservationIgnored private var running: Task<RunEnd, Never>?
    @ObservationIgnored private var draftKind: DocKind?
    @ObservationIgnored private var reply = ""
    @ObservationIgnored private var wroteAt = ContinuousClock.now
    @ObservationIgnored private var shownAt = ContinuousClock.now

    private enum RunEnd { case done(String), stopped(StopReason), refused }

    /// A session on disk. Reads the four files once; they are small.
    init(spec: Spec, app: AppState) {
        let store = SpecStore(folder: spec.folder)
        var documents: [DocKind: String] = [:]
        for kind in DocKind.allCases {
            documents[kind] = try? String(contentsOf: store.url(kind), encoding: .utf8)
        }
        self.spec = spec
        self.documents = documents
        self.liveText = ""
        self.activity = []
        self.isRunning = false
        self.app = app
        self.store = store
        self.saved = documents
        watcher = FileWatcher(folder: spec.folder) { [weak self] kind, text in
            Task { @MainActor in self?.fileChanged(kind, text) }
        }
    }

    private init(spec: Spec, documents: [DocKind: String], liveText: String, activity: [ActivityLine], isRunning: Bool, lastError: String?, conflict: DocKind?) {
        self.spec = spec
        self.documents = documents
        self.liveText = liveText
        self.activity = activity
        self.isRunning = isRunning
        self.lastError = lastError
        self.conflict = conflict
        self.store = nil
    }

    var currentQuestion: Question? { spec.questions.first { $0.answer == nil } }
    var answeredQuestions: [Question] { spec.questions.filter { $0.answer != nil } }

    func summary(_ kind: DocKind) -> DocSummary {
        var summary = MarkdownParser.summary(documents[kind] ?? "", kind: kind)
        if kind == .tasks {
            summary.uncoveredCriteria = MarkdownParser.uncoveredCriteria(requirements: documents[.requirements] ?? "", tasks: documents[.tasks] ?? "")
        }
        return summary
    }

    // MARK: - Discovery

    func start() async {
        guard spec.stage == .discovery, currentQuestion == nil else { return }
        await discoveryTurn()
    }

    func answer(_ answer: Answer) async {
        guard let i = spec.questions.firstIndex(where: { $0.answer == nil }) else { return }
        spec.questions[i].answer = answer
        persist()
        await discoveryTurn()
    }

    /// Records the new answer; the next turn sees it.
    func changeAnswer(questionID: String, to answer: Answer) async {
        guard let i = spec.questions.firstIndex(where: { $0.id == questionID }) else { return }
        spec.questions[i].answer = answer
        persist()
    }

    /// Ends Discovery: the open question and uncovered topics become assumptions.
    func draftNow() async {
        guard spec.stage == .discovery else { return }
        await stop()
        if let i = spec.questions.firstIndex(where: { $0.answer == nil }) { spec.questions[i].answer = .agentDecides }
        lastError = nil
        await finishDiscovery()
    }

    func retry() async {
        guard spec.stage == .discovery, !isRunning else { return }
        await discoveryTurn()
    }

    private func discoveryTurn() async {
        lastError = nil
        let prompt = Prompt.discovery.build(["name": spec.name, "idea": spec.idea, "answers": spec.answersText, "coverage": spec.coverageText])
        let end = await run(prompt, resume: nil, persist: false)
        guard spec.stage == .discovery else { return }
        switch end {
        case .done(let reply):
            guard let turn = try? DiscoveryTurn.decode(reply) else {
                lastError = "Claude Code's reply couldn't be read."
                return
            }
            spec.coverage = turn.coverage
            if var next = turn.next, !turn.done {
                // Question IDs must stay unique; the agent may reuse a topic slug.
                if spec.questions.contains(where: { $0.id == next.id }) {
                    next = Question(id: "\(next.id)-\(spec.questions.count)", title: next.title, why: next.why, shapes: next.shapes, options: next.options)
                }
                spec.questions.append(next)
                persist()
            } else {
                await finishDiscovery()
            }
        case .stopped(.user), .refused:
            break
        case .stopped(let reason):
            lastError = Self.message(reason)
            app?.notify("\(spec.name) stopped", Self.message(reason), nil)
        }
    }

    private func finishDiscovery() async {
        guard spec.apply(.discoveryFinished) else { return }
        persist()
        await draft(.product)
    }

    // MARK: - Drafting and recovery

    func stop() async {
        guard let runner else { return }
        await runner.stop()
        _ = await running?.value
    }

    /// Continues a stopped file from its last complete section. After a usage limit with a
    /// known reset, posts a notification for that time and waits for it first.
    func resume() async {
        guard case .stopped(let kind, let reason) = spec.stage else { return }
        if case .usageLimit(let resetsAt?) = reason, resetsAt > .now {
            app?.notify("\(spec.name) can continue", "Your Claude usage limit has reset. Open Mel and press Resume to finish \(kind.fileName).", resetsAt)
            try? await Task.sleep(for: .seconds(resetsAt.timeIntervalSinceNow))
            guard spec.stage == .stopped(kind, reason) else { return }
        }
        let partial = DraftText.truncatedToLastCompleteSection(documents[kind] ?? "")
        spec.apply(.resume)
        documents[kind] = partial
        write(partial, for: kind)
        await draft(kind, from: partial)
    }

    func finishByHand() {
        guard spec.apply(.finishByHand) else { return }
        persist()
    }

    /// Writes `kind`: fresh, or continuing `partial` in the stored Claude Code session.
    private func draft(_ kind: DocKind, from partial: String = "") async {
        let prompt = partial.isEmpty
            ? Prompt(drafting: kind).build(["name": spec.name, "idea": spec.idea, "answers": spec.answersText, "decide": spec.decideText, "approved": approvedText(before: kind)])
            : Prompt.continue.build(["file": kind.fileName, "partial": partial])
        draftKind = kind
        reply = partial
        liveText = partial
        activity = []
        persist()
        let end = await run(prompt, resume: partial.isEmpty ? nil : spec.sessionID, persist: true)
        draftKind = nil
        liveText = ""
        switch end {
        case .stopped(.sessionNotFound):
            // The stored session is gone: write the file again from the start.
            return await draft(kind)
        case .done(let result):
            let text = DraftText.file(fromReply: reply.isEmpty ? result : reply, kind: kind)
            let final = text.trimmingCharacters(in: .whitespacesAndNewlines) + "\n"
            documents[kind] = final
            write(final, for: kind)
            spec.apply(.draftFinished)
            app?.notify("\(kind.fileName) is ready for review", spec.name, nil)
        case .stopped(let reason):
            let text = DraftText.file(fromReply: reply, kind: kind)
            documents[kind] = text
            write(text, for: kind)
            spec.apply(.draftStopped(reason))
            if reason != .user { app?.notify("\(spec.name) stopped", Self.message(reason), nil) }
        case .refused:
            spec.apply(.draftStopped(.user))
        }
        persist()
    }

    /// A text delta while drafting: the preview updates at most 10 times a second, the file every 500 ms.
    private func received(_ text: String) {
        guard let kind = draftKind else { return }
        reply += text
        let now = ContinuousClock.now
        if now - shownAt >= .milliseconds(100) {
            shownAt = now
            liveText = DraftText.file(fromReply: reply, kind: kind)
        }
        if now - wroteAt >= .milliseconds(500) {
            wroteAt = now
            write(DraftText.file(fromReply: reply, kind: kind), for: kind)
        }
    }

    private func approvedText(before kind: DocKind) -> String {
        DocKind.allCases.prefix { $0 != kind }
            .filter { spec.docs[$0] == .approved }
            .map { "### \($0.fileName)\n\n\(documents[$0] ?? "")" }
            .joined(separator: "\n\n")
    }

    /// One agent run. Only one spec runs at a time (`AppState.runningSpecID`).
    private func run(_ prompt: String, resume: String?, persist persistSession: Bool) async -> RunEnd {
        guard let app else { return .refused }
        guard app.runningSpecID == nil else {
            lastError = "Another spec is running. Wait for it to finish or stop it."
            return .refused
        }
        guard let runner = app.agentRunner() else {
            lastError = "Claude Code isn't ready. Check Settings."
            return .refused
        }
        app.requestNotificationsOnce()
        let request = AgentRequest(prompt: prompt, workingDirectory: projectFolder, resumeSessionID: resume, persistSession: persistSession)
        app.runningSpecID = spec.id
        self.runner = runner
        isRunning = true
        let task = Task { () -> RunEnd in
            var end = RunEnd.stopped(.crashed("Claude Code ended without a result."))
            do {
                loop: for try await event in runner.run(request) {
                    switch event {
                    case .session(let id) where persistSession:
                        spec.sessionID = id
                        persist()
                    case .session, .rateLimit:
                        break
                    case .text(let text):
                        received(text)
                    case .step(let step):
                        activity.append(ActivityLine(at: .now, text: step))
                    case .done(let result):
                        end = .done(result)
                        break loop
                    case .failed(let reason):
                        end = .stopped(reason)
                        break loop
                    }
                }
            } catch {
                end = .stopped(.crashed(error.localizedDescription))
            }
            // Cleared here, before any waiter resumes, so a run started next isn't undone.
            self.runner = nil
            isRunning = false
            if app.runningSpecID == spec.id { app.runningSpecID = nil }
            return end
        }
        running = task
        return await task.value
    }

    private static func message(_ reason: StopReason) -> String {
        switch reason {
        case .usageLimit: "Your plan's usage limit was reached. Try again when it resets."
        case .signedOut: "Claude Code is signed out. Sign in, then try again."
        case .timeout: "Claude Code stopped responding."
        case .crashed, .sessionNotFound, .user: "Claude Code stopped unexpectedly."
        }
    }

    // MARK: - Review

    /// An edit in the app. Written after 500 ms without further edits, unless the file changed
    /// on disk meanwhile: then it's a conflict, never an overwrite.
    func save(_ text: String, for kind: DocKind) {
        guard documents[kind] != text else { return }
        documents[kind] = text
        if spec.apply(.edited(kind)) { persist() }
        pendingSaves[kind]?.cancel()
        pendingSaves[kind] = Task {
            try? await Task.sleep(for: .milliseconds(500))
            guard !Task.isCancelled, let store else { return }
            pendingSaves[kind] = nil
            await io?.value
            if let disk = await store.read(kind), disk != saved[kind] {
                conflictText = disk
                conflict = kind
                return
            }
            write(text, for: kind)
        }
    }

    func confirmAssumption(index: Int, in kind: DocKind) {
        guard let text = documents[kind], let edited = DraftText.confirmAssumption(index, in: text) else { return }
        saveNow(edited, for: kind)
    }

    func changeAssumption(index: Int, to text: String, in kind: DocKind) {
        guard let current = documents[kind], let edited = DraftText.changeAssumption(index, to: text, in: current) else { return }
        saveNow(edited, for: kind)
    }

    /// Approves `kind` (blocked while assumptions remain) and starts the next file.
    func approve(_ kind: DocKind) async {
        if pendingSaves[kind] != nil { saveNow(documents[kind] ?? "", for: kind) }
        guard spec.apply(.approve(kind, assumptionsLeft: summary(kind).assumptions)) else { return }
        persist()
        if case .drafting(let next) = spec.stage { await draft(next) }
    }

    /// Keep Mine writes the editor text; Use File takes the text on disk.
    func resolveConflict(keepMine: Bool) {
        guard let kind = conflict else { return }
        conflict = nil
        if keepMine {
            saveNow(documents[kind] ?? "", for: kind)
        } else {
            pendingSaves.removeValue(forKey: kind)?.cancel()
            documents[kind] = conflictText
            saved[kind] = conflictText
            if spec.apply(.edited(kind)) { persist() }
        }
    }

    private func saveNow(_ text: String, for kind: DocKind) {
        pendingSaves.removeValue(forKey: kind)?.cancel()
        documents[kind] = text
        if spec.apply(.edited(kind)) { persist() }
        write(text, for: kind)
    }

    private func fileChanged(_ kind: DocKind, _ text: String) {
        guard kind != draftKind else { return }
        switch FileWatcher.resolve(fileText: text, editorText: documents[kind] ?? "", savedText: saved[kind] ?? "") {
        case .reload(let text):
            documents[kind] = text
            saved[kind] = text
            if spec.apply(.edited(kind)) { persist() }
        case .conflict(let fileText):
            conflictText = fileText
            conflict = kind
        }
    }

    // MARK: - Handoff and system actions

    var startCommand: String { #"claude "Read specs/ and implement TASKS.md, task 1""# }
    func showInFinder() { SystemActions.showInFinder(spec.folder) }

    func openStartCommandInTerminal() {
        do { try SystemActions.openInTerminal(command: startCommand, in: projectFolder) } catch { lastError = error.localizedDescription }
    }

    func finish(commitToGit: Bool) throws {
        guard commitToGit else { return }
        if !isGitRepository { try Git.initRepository(projectFolder) }
        try Git.commit(paths: Git.specPaths, message: "Add spec for \(spec.name)", in: projectFolder)
    }

    var canCommit: Bool { Git.isAvailable }
    var isGitRepository: Bool { Git.isRepository(projectFolder) }

    func updateIdea(_ idea: String) {
        spec.idea = idea
        persist()
    }

    // MARK: - Disk

    private var projectFolder: URL { spec.folder.deletingLastPathComponent() }

    private func write(_ text: String, for kind: DocKind) {
        guard let store else { return }
        saved[kind] = text
        watcher?.noteWritten(text, for: kind)
        io = Task { [io] in
            await io?.value
            do { try await store.write(text, for: kind) } catch { lastError = error.localizedDescription }
        }
    }

    private func persist() {
        app?.update(spec)
        guard let store else { return }
        let spec = spec
        io = Task { [io] in
            await io?.value
            await store.saveState(spec)
        }
    }

    /// Waits for pending writes and saves the state now. For tests and quitting.
    func flush() async {
        await io?.value
        try? await store?.flushState()
    }

    static func preview(_ spec: Spec, documents: [DocKind: String] = [:], liveText: String = "", activity: [ActivityLine] = [], isRunning: Bool = false, lastError: String? = nil, conflict: DocKind? = nil) -> SpecSession {
        SpecSession(spec: spec, documents: documents, liveText: liveText, activity: activity, isRunning: isRunning, lastError: lastError, conflict: conflict)
    }
}
