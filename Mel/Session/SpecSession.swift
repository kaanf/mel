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
    /// B3: the step the draft has reached (`<!-- mel:step N -->`), 0 before the first marker.
    private(set) var draftStep = 0
    /// Board: the last change's result line, until dismissed or undone.
    private(set) var lastChange: ChangeResult?
    /// Text of each file as Mel last wrote it (`.mel/approved/`), for the edit banner's Update and Undo.
    private(set) var snapshots: [DocKind: String] = [:]
    /// DECISIONS.md, newest first.
    private(set) var decisions: [Decision] = []

    @ObservationIgnored private weak var app: AppState?
    @ObservationIgnored private var store: SpecStore?
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

    /// A session on disk. Reads the spec's files once; they are small.
    init(spec: Spec, app: AppState) {
        let store = SpecStore(folder: spec.folder)
        var documents: [DocKind: String] = [:]
        for kind in spec.size.files {
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
        self.decisions = (try? String(contentsOf: spec.folder.appending(path: "DECISIONS.md"), encoding: .utf8)).map(Decision.parse) ?? []
        watch()
        let files = spec.size.files
        Task {
            var snapshots: [DocKind: String] = [:]
            for kind in files { snapshots[kind] = await store.snapshot(kind) }
            // A file written meanwhile wins.
            self.snapshots = snapshots.merging(self.snapshots) { _, new in new }
        }
    }

    private init(spec: Spec, documents: [DocKind: String], liveText: String, activity: [ActivityLine], isRunning: Bool, lastError: String?, conflict: DocKind?, draftStep: Int, snapshots: [DocKind: String], decisions: [Decision]) {
        self.draftStep = draftStep
        self.snapshots = snapshots
        self.decisions = decisions
        self.spec = spec
        self.documents = documents
        self.liveText = liveText
        self.activity = activity
        self.isRunning = isRunning
        self.lastError = lastError
        self.conflict = conflict
        self.store = nil
    }

    var currentQuestion: Question? { spec.questions.first { $0.round == .intake && $0.answer == nil } }
    var answeredQuestions: [Question] { spec.questions.filter { $0.round == .intake && $0.answer != nil } }

    /// The tasks on Ready and in Build order.
    var tasks: [SpecTask] { SpecTask.parse(documents[.tasks] ?? "") }

    func summary(_ kind: DocKind) -> DocSummary {
        var summary = MarkdownParser.summary(documents[kind] ?? "", kind: kind)
        if kind == .tasks {
            summary.uncoveredCriteria = MarkdownParser.uncoveredCriteria(requirements: documents[.requirements] ?? "", tasks: documents[.tasks] ?? "")
        }
        return summary
    }

    // MARK: - Intake

    /// One run returns every intake question at once. With none to ask, the board starts writing.
    func start() async {
        guard spec.stage == .discovery, !spec.questions.contains(where: { $0.round == .intake }) else { return }
        lastError = nil
        let end = await run(intakePrompt, step: .questions, resume: nil, persist: false)
        guard spec.stage == .discovery else { return }
        switch end {
        case .done(let reply):
            guard let intake = try? Intake.decode(reply, size: spec.size) else {
                lastError = "Claude Code's reply couldn't be read."
                return
            }
            if let name = intake.name, spec.name == Spec.untitledName { await rename(to: name) }
            spec.coverage = intake.coverage
            spec.questions = Self.unique(intake.questions, after: [])
            persist()
            if currentQuestion == nil { await beginBoard() }
        case .stopped(.user), .refused:
            break
        case .stopped(let reason):
            lastError = Self.message(reason)
            app?.notify("\(spec.name) stopped", Self.message(reason), nil)
        }
    }

    /// A topic is covered once the user answers its question.
    private func cover(_ question: Question) {
        guard question.answer != nil, question.answer != .agentDecides else { return }
        for i in spec.coverage.indices where spec.coverage[i].question == question.id { spec.coverage[i].state = .covered }
    }

    /// Intake named an untitled spec: before any file is written, its folder takes the name.
    private func rename(to name: String) async {
        await flush()
        watcher = nil
        if let folder = try? app?.rename(spec.id, to: name) {
            spec.folder = folder
            store = SpecStore(folder: folder)
        }
        spec.name = name
        watch()
    }

    private func watch() {
        watcher = FileWatcher(folder: spec.folder) { [weak self] kind, text in
            Task { @MainActor in self?.fileChanged(kind, text) }
        }
    }

    // MARK: - Agent runs

    func stop() async {
        guard let runner else { return }
        await runner.stop()
        _ = await running?.value
    }

    /// A text delta while drafting: the preview updates at most 10 times a second, the file every 500 ms.
    private func received(_ text: String) {
        guard let kind = draftKind else { return }
        reply += text
        let now = ContinuousClock.now
        if now - shownAt >= .milliseconds(100) {
            shownAt = now
            liveText = DraftText.file(fromReply: reply, kind: kind)
            draftStep = DraftText.step(in: reply)
        }
        if now - wroteAt >= .milliseconds(500) {
            wroteAt = now
            write(DraftText.file(fromReply: reply, kind: kind), for: kind)
        }
    }

    /// One agent run. Only one runs at a time across the app (`AppState.isAgentBusy`).
    private func run(_ prompt: String, step: TokenStep, resume: String?, persist persistSession: Bool, tools: Bool = true) async -> RunEnd {
        guard let app else { return .refused }
        guard !app.isAgentBusy else {
            lastError = "Another spec is running. Wait for it to finish or stop it."
            return .refused
        }
        guard let runner = app.agentRunner() else {
            lastError = "Claude Code isn't ready. Check Settings."
            return .refused
        }
        lastError = nil
        app.requestNotificationsOnce()
        let request = AgentRequest(prompt: prompt, workingDirectory: projectFolder, resumeSessionID: resume, persistSession: persistSession, allowsTools: tools)
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
                    case .usage(let tokens):
                        spec.addTokens(tokens, to: step)
                        persist()
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

    // MARK: - Edits and conflicts

    /// An edit in the app. Written after 500 ms without further edits, unless the file changed
    /// on disk meanwhile: then it's a conflict, never an overwrite.
    func save(_ text: String, for kind: DocKind) {
        guard documents[kind] != text else { return }
        documents[kind] = text
        markEdited(kind)
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
            markEdited(kind)
        }
    }

    private func saveNow(_ text: String, for kind: DocKind) {
        pendingSaves.removeValue(forKey: kind)?.cancel()
        documents[kind] = text
        markEdited(kind)
        write(text, for: kind)
    }

    private func fileChanged(_ kind: DocKind, _ text: String) {
        guard kind != draftKind else { return }
        switch FileWatcher.resolve(fileText: text, editorText: documents[kind] ?? "", savedText: saved[kind] ?? "") {
        case .reload(let text):
            documents[kind] = text
            saved[kind] = text
            markEdited(kind)
        case .conflict(let fileText):
            conflictText = fileText
            conflict = kind
        }
    }

    /// A written file the user changed becomes `edited`; the files built on it wait for Update or Keep.
    private func markEdited(_ kind: DocKind) {
        if spec.editedOnBoard(kind) { persist() }
    }

    // MARK: - Board (V2.md §0)

    /// Answers the intake question on screen; after the last one the board starts writing.
    func answerIntake(_ answer: Answer) async {
        guard let card = spec.intakeCard else { return }
        spec.answer(card: card.id, answer)
        if let question = spec.questions.first(where: { $0.id == card.id }) { cover(question) }
        persist()
        if spec.intakeCard == nil { await beginBoard() }
    }

    /// "Skip, write the plan now": the questions left become guesses.
    func skipIntake() async {
        guard spec.stage == .discovery else { return }
        await stop()
        lastError = nil
        await beginBoard()
    }

    private func beginBoard() async {
        guard spec.stage == .discovery else { return }
        for (n, q) in spec.questions.enumerated() where q.answer != nil && q.answer != .agentDecides {
            addDecision(title: q.title, reason: q.answerText ?? "", source: "Intake Q\(n + 1)")
        }
        spec.startBoard()
        persist()
        await runBoard()
    }

    /// Answers a card or changes an answer (also an intake answer, once files exist).
    func answerCard(_ id: String, _ answer: Answer) async {
        spec.answer(card: id, answer)
        let card = spec.cards.first { $0.id == id } ?? spec.questions.first { $0.id == id }.map(Card.init)
        if answer != .agentDecides, let card, let text = card.answerText {
            addDecision(title: card.text, reason: text, source: card.disagrees ? "You settled a conflict" : "Your answer")
        }
        persist()
        await runBoard()
    }

    /// Change on an answered card.
    func reopenCard(_ id: String) {
        spec.reopen(card: id)
        persist()
    }

    /// "Write it now": open cards become guesses and the next file starts.
    func writeNow() async {
        spec.writeNow()
        persist()
        await runBoard()
    }

    /// Runs whatever the board can do without the user. Safe to call at any time.
    func continueBoard() async {
        await runBoard()
    }

    private func runBoard() async {
        var ran = false
        while !isRunning, let step = spec.nextStep {
            let went: Bool
            switch step {
            case .draft(let kind): went = await draftOnBoard(kind)
            case .change: went = await applyAnswers()
            case .check: went = await check()
            }
            persist()
            guard went else { return }
            ran = true
        }
        guard ran else { return }
        if spec.isReady {
            app?.notify("\(spec.name) is ready", "The plan is written. Open Mel to start building.", nil)
        } else if !spec.openCards.isEmpty {
            let count = spec.openCards.count
            app?.notify("Mel needs you", "\(count) \(count == 1 ? "question" : "questions") about \(spec.name).", nil)
        }
    }

    /// Streams `kind` into its file and returns how the run ended; `reply` holds the text.
    private func stream(_ kind: DocKind, prompt: String, step: TokenStep, from partial: String = "") async -> RunEnd {
        draftKind = kind
        reply = partial
        liveText = partial
        draftStep = 0
        activity = []
        persist()
        let end = await run(prompt, step: step, resume: partial.isEmpty ? nil : spec.sessionID, persist: true)
        draftKind = nil
        liveText = ""
        return end
    }

    /// Writes `kind`, or continues it from its last complete section after a stop.
    private func draftOnBoard(_ kind: DocKind, fresh: Bool = false) async -> Bool {
        let partial = !fresh && spec.docs[kind] == .stopped ? DraftText.truncatedToLastCompleteSection(documents[kind] ?? "") : ""
        spec.begin(.draft(kind))
        if !partial.isEmpty {
            documents[kind] = partial
            write(partial, for: kind)
        }
        let prompt = partial.isEmpty
            ? Prompt(drafting: kind).build(promptValues(drafting: kind), fillGaps: spec.fillGaps, language: spec.language)
            : Prompt.continue.build(["file": kind.fileName, "partial": partial], language: spec.language)
        switch await stream(kind, prompt: prompt, step: TokenStep(file: kind), from: partial) {
        case .stopped(.sessionNotFound):
            return await draftOnBoard(kind, fresh: true)
        case .done(let result):
            let full = reply.isEmpty ? result : reply
            let final = DraftText.file(fromReply: full, kind: kind).trimmingCharacters(in: .whitespacesAndNewlines) + "\n"
            documents[kind] = final
            write(final, for: kind)
            saveSnapshot(kind)
            let asked = DraftText.questions(in: full, kind: kind).map { $0.with(id: "\(kind.rawValue)-\($0.id)") } + OpenQuestion.parse(final, kind: kind).map(Question.init)
            spec.drafted(kind, asked: Self.unique(asked, after: spec.questions.filter { $0.answer != nil || $0.shapes != kind }))
            return true
        case .stopped(let reason):
            let text = DraftText.file(fromReply: reply, kind: kind)
            documents[kind] = text
            write(text, for: kind)
            spec.halt(reason, during: .draft(kind))
            if reason != .user { app?.notify("\(spec.name) stopped", Self.message(reason), nil) }
            return false
        case .refused:
            spec.halt(.user, during: .draft(kind))
            return false
        }
    }

    // MARK: Changes

    /// The line under Tell Mel after a change (V2-4), with what Undo needs.
    struct ChangeResult: Hashable {
        /// "Changed 2 places in REQUIREMENTS.md, 1 in TASKS.md".
        var line: String
        var tokens: Int
        /// The new text of each changed passage, highlighted in an open file.
        var passages: [DocKind: [String]]
        fileprivate var before: [DocKind: String] = [:]
        fileprivate var decision: String?

        init(line: String, tokens: Int, passages: [DocKind: [String]]) {
            self.line = line
            self.tokens = tokens
            self.passages = passages
        }
    }

    private enum ChangeEnd {
        case applied, unplaced, stopped(StopReason), unreadable, refused

        var isApplied: Bool { if case .applied = self { true } else { false } }
    }

    /// One change run over the written files: applies its edits, or records the files where they don't fit.
    private func change(_ requests: [String], attachments: [Attachment] = [], answers: Bool) async -> ChangeEnd {
        let written = spec.written
        guard let first = written.first else { return .refused }
        var values = promptValues(drafting: first)
        values["reading"] = attachments.isEmpty
            ? "Everything you need is in this prompt. Do not read files or call tools."
            : "You may open the attachments below with Read. Everything else you need is in this prompt."
        values["requests"] = requests.map { "- " + $0 }.joined(separator: "\n")
        values["attachments"] = attachments.isEmpty ? "(none)" : attachments.map { "- specs/\(slug)/.mel/attachments/\($0.fileName)" }.joined(separator: "\n")
        values["current"] = text(of: written)
        values["kinds"] = written.map { "`\($0.rawValue)`" }.joined(separator: ", ")
        let spent = spec.tokens?[.changes] ?? 0
        activity = []
        lastChange = nil
        let end = await run(Prompt.change.build(values, fillGaps: spec.fillGaps, language: spec.language), step: .changes, resume: nil, persist: false, tools: !attachments.isEmpty)
        switch end {
        case .done(let reply):
            guard let change = try? Change.decode(reply) else { return .unreadable }
            let current = Dictionary(uniqueKeysWithValues: written.map { ($0, documents[$0] ?? "") })
            guard let texts = change.apply(to: current) else {
                spec.unplacedChange = UnplacedChange(request: requests.joined(separator: "\n"), change: change, files: change.unplaced(in: current), answers: answers)
                return .unplaced
            }
            install(texts, line: change.summary(order: written), passages: Dictionary(grouping: change.edits, by: \.file).mapValues { $0.map(\.new) }, spent: spent)
            return .applied
        case .stopped(let reason):
            return .stopped(reason)
        case .refused:
            return .refused
        }
    }

    /// Puts changed files in place (text, disk, snapshot), reruns Mel's own checks and sets the result line.
    private func install(_ texts: [DocKind: String], line: String, passages: [DocKind: [String]] = [:], spent: Int) {
        var before: [DocKind: String] = [:]
        for (kind, text) in texts {
            before[kind] = documents[kind]
            let final = text.trimmingCharacters(in: .whitespacesAndNewlines) + "\n"
            documents[kind] = final
            write(final, for: kind)
            saveSnapshot(kind)
        }
        refreshChecks()
        var result = ChangeResult(line: line, tokens: (spec.tokens?[.changes] ?? 0) - spent, passages: passages)
        result.before = before
        lastChange = result
    }

    /// Mel's own checks by ID, free, after the files changed. Contradictions keep their cards.
    private func refreshChecks() {
        guard var analysis = spec.analysis else { return }
        analysis.refresh(requirements: documents[.requirements] ?? "", experience: spec.size.files.contains(.experience) ? documents[.experience] ?? "" : nil, tasks: documents[.tasks] ?? "")
        spec.checked(analysis)
    }

    /// The answers given since the files were written, in one run.
    private func applyAnswers() async -> Bool {
        switch await change(spec.changeRequests, answers: true) {
        case .applied:
            spec.changed()
            return true
        case .unplaced, .refused:
            return false
        case .stopped(let reason):
            spec.halt(reason, during: .change)
            if reason != .user { app?.notify("\(spec.name) stopped", Self.message(reason), nil) }
            return false
        case .unreadable:
            lastError = "Claude Code's reply couldn't be read."
            spec.halt(.crashed("Claude Code's reply couldn't be read."), during: .change)
            return false
        }
    }

    /// Tell Mel: one request against the written files, with the user's words as the decision's
    /// reason. False when the run didn't finish: the request stays in the box.
    @discardableResult
    func tell(_ request: String, files: [URL] = []) async -> Bool {
        let request = request.trimmingCharacters(in: .whitespacesAndNewlines)
        guard spec.stage == .board, !isRunning, !request.isEmpty, !spec.written.isEmpty, spec.halted == nil, spec.unplacedChange == nil else { return false }
        var attachments: [Attachment] = []
        if let store {
            for file in files { if let attachment = try? await store.attach(copying: file) { attachments.append(attachment) } }
            spec.attachments += attachments
        }
        let end = await change([request], attachments: attachments, answers: false)
        defer { persist() }
        switch end {
        case .applied:
            lastChange?.decision = addDecision(title: Self.title(request), reason: request, source: "Tell Mel")
            persist()
            await runBoard()
            return true
        case .unplaced:
            return true   // V2-7 takes over; Cancel hands the request back
        case .stopped(let reason):
            if reason != .user { lastError = Self.message(reason) }
            return false
        case .unreadable:
            lastError = "Claude Code's reply couldn't be read."
            return false
        case .refused:
            return false
        }
    }

    /// Undo on the result line: the changed files go back as they were.
    func undoChange() {
        guard let change = lastChange, !isRunning else { return }
        for (kind, text) in change.before {
            documents[kind] = text
            write(text, for: kind)
            saveSnapshot(kind)
        }
        if let id = change.decision { removeDecision(id) }
        lastChange = nil
        refreshChecks()
        persist()
    }

    func dismissChange() {
        lastChange = nil
    }

    /// "Rewrite FILE" (V2-7): the agent writes the first unplaced file whole. It is the only whole
    /// rewrite, and always the user's choice. The edits that did fit go in once no file is left.
    func rewriteUnplaced() async {
        guard var unplaced = spec.unplacedChange, let kind = unplaced.files.first, !isRunning else { return }
        let before = documents[kind] ?? ""
        var values = promptValues(drafting: kind)
        values["file"] = kind.fileName
        values["instruction"] = unplaced.request
        values["current"] = before
        values["approved"] = text(of: spec.written.filter { $0 != kind })
        let spent = spec.tokens?[.changes] ?? 0
        let end = await stream(kind, prompt: Prompt.rewrite.build(values, fillGaps: spec.fillGaps, language: spec.language), step: .changes)
        guard case .done(let result) = end else {
            // Nothing changes on a stop: the file goes back and the offer stays.
            write(before, for: kind)
            if case .stopped(let reason) = end, reason != .user { lastError = Self.message(reason) }
            persist()
            return
        }
        var texts = [kind: DraftText.file(fromReply: reply.isEmpty ? result : reply, kind: kind)]
        unplaced.files.removeFirst()
        unplaced.change = unplaced.change.without([kind])
        if unplaced.files.isEmpty {
            let current = Dictionary(uniqueKeysWithValues: spec.written.map { ($0, documents[$0] ?? "") })
            texts.merge(unplaced.change.apply(to: current) ?? [:]) { rewritten, _ in rewritten }
            spec.unplacedChange = nil
            if unplaced.answers { spec.changed() }
        } else {
            spec.unplacedChange = unplaced
        }
        install(texts, line: "Rewrote \(kind.fileName)", spent: spent)
        lastChange?.decision = addDecision(title: "Rewrote \(kind.fileName)", reason: unplaced.request, source: "You chose a full rewrite")
        persist()
        await runBoard()
    }

    /// Cancel on the same offer: nothing changed. Returns a typed request for the Tell Mel box.
    @discardableResult
    func cancelUnplaced() async -> String {
        guard let unplaced = spec.unplacedChange, !isRunning else { return "" }
        spec.unplacedChange = nil
        if unplaced.answers { spec.changed() }
        persist()
        await runBoard()
        return unplaced.answers ? "" : unplaced.request
    }

    // MARK: Plan

    var stories: [Story] { Story.parse(documents[.requirements] ?? "") }

    /// First version ↔ Later: Mel edits the story's tag itself, at once and with no run.
    func moveStory(_ id: String, toLater: Bool) {
        guard !isRunning, let text = documents[.requirements], let moved = Story.move(id, toLater: toLater, in: text), moved != text else { return }
        documents[.requirements] = moved
        write(moved, for: .requirements)
        saveSnapshot(.requirements)
        refreshChecks()
        persist()
    }

    /// What Remove… on a story card would take with it.
    func removal(ofStory id: String) -> StoryRemoval? {
        StoryRemoval(story: id, requirements: documents[.requirements] ?? "", experience: spec.size.files.contains(.experience) ? documents[.experience] : nil, tasks: documents[.tasks] ?? "")
    }

    /// Remove: Mel cuts the story from REQUIREMENTS.md; one change run takes out what was built on it.
    func removeStory(_ id: String) async {
        guard spec.stage == .board, !isRunning, spec.halted == nil, spec.unplacedChange == nil, let removal = removal(ofStory: id) else { return }
        let before = documents[.requirements] ?? ""
        let requests = spec.written.compactMap { removal.instruction(for: $0) }
        documents[.requirements] = removal.requirements
        write(removal.requirements, for: .requirements)
        lastChange = nil
        if !requests.isEmpty, case let end = await change(requests, answers: false), !end.isApplied {
            // All or nothing: the story goes back.
            spec.unplacedChange = nil
            documents[.requirements] = before
            write(before, for: .requirements)
            lastError = "Mel couldn't remove what was built on “\(removal.title)”. Nothing was changed."
            persist()
            return
        }
        saveSnapshot(.requirements)
        var result = lastChange ?? ChangeResult(line: "", tokens: 0, passages: [:])
        result.line = "Removed “\(removal.title)”"
        result.before[.requirements] = before
        result.decision = addDecision(title: "Removed: \(removal.title)", reason: removal.summary.isEmpty ? "Nothing else was built on it." : removal.summary, source: "You")
        lastChange = result
        spec.removedStories = (spec.removedStories ?? []) + [RemovedStory(id: id, title: removal.title, section: removal.section)]
        refreshChecks()
        persist()
        await runBoard()
    }

    /// Restore in DECISIONS.md: one change run puts the story back with what it needs.
    func restoreStory(_ id: String) async {
        guard spec.stage == .board, !isRunning, spec.halted == nil, spec.unplacedChange == nil, let removed = spec.removedStories?.first(where: { $0.id == id }) else { return }
        let request = "Put story \(removed.id) “\(removed.title)” back into REQUIREMENTS.md as it was below, in its place by number, and add back what the other files need for it:\n\n\(removed.section)"
        switch await change([request], answers: false) {
        case .applied, .unplaced:
            spec.removedStories?.removeAll { $0.id == id }
            lastChange?.decision = addDecision(title: "Restored: \(removed.title)", reason: "", source: "You")
        case .stopped(let reason):
            if reason != .user { lastError = Self.message(reason) }
        case .unreadable:
            lastError = "Claude Code's reply couldn't be read."
        case .refused:
            break
        }
        persist()
        await runBoard()
    }

    // MARK: Edits by hand, stops, checks, ready

    /// The edit banner's Update: one change run brings the files built on the edit in line.
    func updateAfterEdit(why: String) async {
        let edited = spec.size.files.filter { spec.docs[$0] == .edited }
        guard !edited.isEmpty, !isRunning else { return }
        let requests = edited.map { kind in
            "The user edited \(kind.fileName) by hand. \(Self.diff(before: snapshots[kind] ?? "", after: documents[kind] ?? ""))\nChange the other files to match; leave \(kind.fileName) as it is." + (why.isEmpty ? "" : " Why: \(why)")
        }
        switch await change(requests, answers: false) {
        case .applied:
            await keepEdit(why: why)
        case .stopped(let reason):
            if reason != .user { lastError = Self.message(reason) }
        case .unreadable:
            lastError = "Claude Code's reply couldn't be read."
        case .unplaced, .refused:
            break   // an unplaced Update shows V2-7; the banner stays for Keep or Undo
        }
        persist()
    }

    /// "Keep them as they are" (and Done when nothing was built on the edit).
    func keepEdit(why: String) async {
        let edited = spec.size.files.filter { spec.docs[$0] == .edited }
        guard !edited.isEmpty else { return }
        edited.forEach(saveSnapshot)
        spec.settleEdit()
        if !why.isEmpty { addDecision(title: "Edited \(edited.map(\.fileName).joined(separator: ", "))", reason: why, source: "You") }
        persist()
        await runBoard()
    }

    /// Undo on the banner: the edited files go back to what Mel last wrote.
    func undoBoardEdit() async {
        for kind in spec.size.files where spec.docs[kind] == .edited {
            guard let text = snapshots[kind] else { continue }
            pendingSaves.removeValue(forKey: kind)?.cancel()
            documents[kind] = text
            write(text, for: kind)
        }
        spec.settleEdit()
        persist()
        await runBoard()
    }

    /// The lines an edit removed and added.
    private static func diff(before: String, after: String) -> String {
        let old = before.split(whereSeparator: \.isNewline).map(String.init)
        let new = after.split(whereSeparator: \.isNewline).map(String.init)
        var removed: [String] = [], added: [String] = []
        for change in new.difference(from: old) {
            switch change {
            case .remove(_, let line, _): removed.append(line)
            case .insert(_, let line, _): added.append(line)
            }
        }
        return (removed.isEmpty ? "" : "Lines removed:\n\(removed.joined(separator: "\n"))\n") + (added.isEmpty ? "" : "Lines added:\n\(added.joined(separator: "\n"))")
    }

    /// The stopped banner's Resume. After a usage limit with a known reset it waits for it and notifies.
    func resumeBoard() async {
        guard let halt = spec.halted, !isRunning else { return }
        if case .usageLimit(let resetsAt?) = halt.reason, resetsAt > .now {
            app?.notify("\(spec.name) can continue", "Your Claude usage limit has reset. Open Mel and press Resume.", resetsAt)
            try? await Task.sleep(for: .seconds(resetsAt.timeIntervalSinceNow))
            guard spec.halted == halt else { return }
        }
        spec.resume()
        lastError = nil
        persist()
        await runBoard()
    }

    /// Why the board stopped, in the user's words.
    var haltText: String? { spec.halted.map { Self.message($0.reason) } }

    /// Open in Editor, in the app chosen in Settings › Specs.
    func openInEditor(_ file: String) {
        SystemActions.open(spec.folder.appending(path: file), with: app?.editor)
    }

    func showInFinder(_ kind: DocKind) {
        guard let store else { return }
        SystemActions.showInFinder(store.url(kind))
    }

    /// "Finish it myself": the cut-off file counts as written; the board goes on after the user's edit.
    func finishBoardByHand() {
        spec.finishByHand()
        persist()
    }

    /// "Check again": looks for contradictions once more, on request (OQ #33).
    func checkAgain() async {
        guard spec.stage == .board, !isRunning, spec.halted == nil, spec.size.hasAnalyze, spec.written == spec.size.files else { return }
        _ = await check()
        persist()
        await runBoard()
    }

    /// After the last file: Mel's coverage by ID, plus one run that only looks for contradictions.
    private func check() async -> Bool {
        let earlier = spec.analysis?.issues.filter { $0.kind == .contradiction && $0.answer == nil }.map { "- \($0.id) (\($0.location)): \($0.text)" } ?? []
        spec.begin(.check)
        lastError = nil
        persist()
        let values = ["name": spec.name, "approved": text(of: spec.written), "kinds": spec.size.kindsText,
                      "earlier": earlier.isEmpty ? "(none: this is the first check)" : earlier.joined(separator: "\n")]
        switch await run(Prompt.analyze.build(values, language: spec.language), step: .checks, resume: nil, persist: false, tools: false) {
        case .done(let reply):
            if let contradictions = try? AnalyzeResult.contradictions(in: reply) {
                var result = AnalyzeResult.coverage(requirements: documents[.requirements] ?? "", experience: spec.size.files.contains(.experience) ? documents[.experience] ?? "" : nil, tasks: documents[.tasks] ?? "")
                result.add(contradictions)
                spec.checked(result)
            } else {
                spec.checkFailed()
                lastError = "Claude Code's reply couldn't be read."
            }
            return true
        case .stopped(let reason):
            spec.halt(reason, during: .check)
            if reason != .user { app?.notify("\(spec.name) stopped", Self.message(reason), nil) }
            return false
        case .refused:
            spec.halt(.user, during: .check)
            return false
        }
    }

    /// "Start Building": writes the task prompts and, as Settings › Specs says, AGENTS.md and the commit.
    func startBuilding(commitToGit: Bool, writeAgentsFile: Bool) async throws {
        guard spec.isReady else { return }
        try await finish(commitToGit: commitToGit, writeAgentsFile: writeAgentsFile)
        spec.startBuilding()
        persist()
    }

    // MARK: - Attachments

    func attach(_ files: [URL]) async throws {
        guard let store else { return }
        for file in files { spec.attachments.append(try await store.attach(copying: file)) }
        persist()
    }

    func attachLog(_ text: String) async throws {
        guard let store else { return }
        spec.attachments.append(try await store.attachLog(text))
        persist()
    }

    func removeAttachment(_ attachment: Attachment) async throws {
        try await store?.remove(attachment)
        spec.attachments.removeAll { $0 == attachment }
        persist()
    }

    // MARK: - Handoff and system actions

    private var slug: String { spec.folder.lastPathComponent }

    var startCommand: String {
        spec.size == .quickFix
            ? #"claude "Read specs/\#(slug)/SPEC.md and fix it""#
            : #"claude "Read specs/\#(slug)/prompts/task-01.md and do it""#
    }

    func showInFinder() { SystemActions.showInFinder(spec.folder) }

    /// "Build with Claude Code": Terminal opens in the project with task 1's prompt, and the spec is Building.
    func build() {
        do {
            try SystemActions.openInTerminal(command: startCommand, in: projectFolder)
            setBuild(.building)
        } catch {
            lastError = error.localizedDescription
        }
    }

    /// The sidebar's Building and Done groups; Mel can't see the coding agent, so the user moves a spec on.
    func setBuild(_ state: BuildState?) {
        guard spec.stage == .done else { return }
        spec.build = state
        persist()
    }

    /// Copy Prompt on Ready: the text of `prompts/task-NN.md`.
    func copyPrompt(of task: SpecTask) {
        SystemActions.copy(task.prompt(requirements: documents[.requirements] ?? ""))
    }

    /// Writes `prompts/task-NN.md`.
    func writeTaskPrompts() async throws -> [URL] {
        guard let store, spec.size.files.contains(.tasks) else { return [] }
        return try await store.writeTaskPrompts(tasks, requirements: documents[.requirements] ?? "")
    }

    /// "Write AGENTS.md": adds or updates Mel's marked block only.
    private func writeAgentsMD() throws {
        let url = projectFolder.appending(path: "AGENTS.md")
        let existing = try? String(contentsOf: url, encoding: .utf8)
        let files = spec.size.files.map(\.fileName).joined(separator: ", ")
        let context = FileManager.default.fileExists(atPath: ProjectStore.contextFolder(project: projectFolder).path)
            ? "Read the project context in `.mel/project/` (product, tech, structure, principles) first. " : ""
        let block = """
        ## Spec: \(spec.name)

        \(context)The spec is in `specs/\(slug)/` (\(files), DECISIONS.md). \(spec.size == .quickFix ? "" : "Work one task at a time from `specs/\(slug)/prompts/`. ")Read DECISIONS.md before changing behavior. Mel writes these files; propose changes instead of editing them.
        """
        try Data(AgentsFile.merge(existing: existing, block: block).utf8).write(to: url, options: .atomic)
    }

    /// Writes the task prompts and, if asked, AGENTS.md; then commits `specs/<slug>/` (minus `.mel/`),
    /// `.mel/project/` and AGENTS.md.
    private func finish(commitToGit: Bool, writeAgentsFile: Bool) async throws {
        _ = try await writeTaskPrompts()
        if writeAgentsFile { try writeAgentsMD() }
        guard commitToGit else { return }
        let (project, slug, message) = (projectFolder, slug, "Add spec for \(spec.name)")
        try await Task.detached {
            if !Git.isRepository(project) { try Git.initRepository(project) }
            let agents = writeAgentsFile ? ["AGENTS.md"] : []
            try Git.commit(paths: Git.specPaths(slug: slug, project: project) + agents, message: message, in: project)
        }.value
    }

    var canCommit: Bool { Git.isAvailable }

    // MARK: - Prompt text

    private var intakePrompt: String {
        var values = promptValues(drafting: spec.size.files[0])
        values["size"] = ["Quick fix", "Feature", "Product"][SpecSize.allCases.firstIndex(of: spec.size)!]
        values["topics"] = spec.size.topics.map { "- \($0)" }.joined(separator: "\n")
        values["count"] = String(spec.size.intakeQuestions)
        values["kinds"] = spec.size.kindsText
        return Prompt.intake.build(values, language: spec.language)
    }

    private func promptValues(drafting kind: DocKind) -> [String: String] {
        let project = app?.contexts[Project(folder: spec.project).id]?.promptText
        let attachments = spec.attachments.map { "- specs/\(slug)/.mel/attachments/\($0.fileName)" }
        return ["name": spec.name, "idea": spec.idea, "files": spec.size.filesText,
                "project": project ?? "(no project context yet)",
                "buildsOn": spec.buildsOn.isEmpty ? "(nothing named)" : spec.buildsOn.joined(separator: ", "),
                "attachments": attachments.isEmpty ? "(none)" : attachments.joined(separator: "\n"),
                "answers": spec.answersText, "decide": spec.decideText,
                "approved": approvedText(before: kind), "steps": kind.stepsText]
    }

    /// The files written before `kind`.
    private func approvedText(before kind: DocKind) -> String {
        text(of: spec.size.files.prefix { $0 != kind }.filter(spec.written.contains))
    }

    private func text(of kinds: [DocKind]) -> String {
        let text = kinds.map { "### \($0.fileName)\n\n\(documents[$0] ?? "")" }.joined(separator: "\n\n")
        return text.isEmpty ? "(none yet)" : text
    }

    // MARK: - Decisions

    @discardableResult
    private func addDecision(title: String, reason: String, source: String, replaces: String? = nil, affects: [String] = []) -> String {
        let id = Decision.nextID(after: decisions)
        decisions.insert(Decision(id: id, title: title, reason: reason, source: source, date: .now, replaces: replaces, affects: affects), at: 0)
        saveDecisions()
        return id
    }

    /// Takes back the decision an undone change logged.
    private func removeDecision(_ id: String) {
        decisions.removeAll { $0.id == id }
        saveDecisions()
    }

    private func saveDecisions() {
        guard let store else { return }
        let decisions = decisions
        io = Task { [io] in
            await io?.value
            do { try await store.writeDecisions(decisions) } catch { lastError = error.localizedDescription }
        }
    }

    /// The first sentence, at most 60 characters.
    private static func title(_ text: String) -> String {
        let sentence = text.split(separator: "\n").first.map { $0.split(separator: ". ").first.map(String.init) ?? String($0) } ?? text
        let trimmed = sentence.trimmingCharacters(in: .whitespacesAndNewlines.union(["."]))
        return trimmed.count > 60 ? String(trimmed.prefix(59)) + "…" : trimmed
    }

    /// Question IDs must stay unique; the agent may reuse a slug.
    private static func unique(_ questions: [Question], after existing: [Question]) -> [Question] {
        var taken = Set(existing.map(\.id))
        return questions.map { q in
            let q = taken.contains(q.id) ? q.with(id: "\(q.id)-\(taken.count)") : q
            taken.insert(q.id)
            return q
        }
    }

    // MARK: - Disk

    private var projectFolder: URL { spec.project }

    private func saveSnapshot(_ kind: DocKind) {
        let text = documents[kind] ?? ""
        snapshots[kind] = text
        guard let store else { return }
        io = Task { [io] in
            await io?.value
            do { try await store.saveSnapshot(text, for: kind) } catch { lastError = error.localizedDescription }
        }
    }

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

    static func preview(_ spec: Spec, documents: [DocKind: String] = [:], liveText: String = "", activity: [ActivityLine] = [], isRunning: Bool = false, lastError: String? = nil, conflict: DocKind? = nil, draftStep: Int = 0, snapshots: [DocKind: String] = [:], decisions: [Decision] = [], lastChange: ChangeResult? = nil) -> SpecSession {
        let session = SpecSession(spec: spec, documents: documents, liveText: liveText, activity: activity, isRunning: isRunning, lastError: lastError, conflict: conflict, draftStep: draftStep, snapshots: snapshots, decisions: decisions)
        session.lastChange = lastChange
        return session
    }
}

private extension Question {
    func with(id: String) -> Question {
        Question(id: id, title: title, why: why, shapes: shapes, round: round, options: options, answer: answer, about: about)
    }
}
