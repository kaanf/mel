import Foundation
import Observation
import MelAgent
import MelSpec
import MelStorage
import MelSystem

@Observable final class SpecSession {
    private(set) var spec: Spec
    private(set) var documents: [DocKind: String] { didSet { reparse(from: oldValue) } }
    /// What the views read from the files, parsed once per change of a file rather than on every view
    /// pass (a 60 KB REQUIREMENTS.md takes ~5 ms; the board read it several times a pass).
    private(set) var blocks: [DocKind: [Block]] = [:]
    /// The tasks on Build and in Build order.
    private(set) var tasks: [SpecTask] = []
    /// V2-3: the tasks in steps.
    private(set) var steps: [BuildStep] = []
    /// Tasks whose check is running now.
    private(set) var checking: Set<Int> = []
    /// Tasks git has no commit for since their prompt was copied, after Check it or Mark done.
    private(set) var uncommitted: Set<Int> = []
    private(set) var stories: [Story] = []
    private var summaries: [DocKind: DocSummary] = [:]
    private(set) var liveText: String
    private(set) var activity: [ActivityLine]
    private(set) var isRunning: Bool
    private(set) var lastError: String?
    private(set) var conflict: DocKind?
    /// Board: the last change's result line, until dismissed or undone.
    private(set) var lastChange: ChangeResult?
    /// Build: the task a running Tell Mel request came from; its check waits for the change (V2-12).
    private(set) var tellingTask: Int?
    /// V2-17: the task Mel is running with Claude Code; one at a time.
    private(set) var runningTask: Int?
    /// V2-20: Run refused because these files have changes that aren't committed.
    private(set) var blockedRun: BlockedRun?
    struct BlockedRun: Hashable { var task: Int; var files: [String] }
    /// What the run's permission rules refused (`permission_denials`), for its report.
    private var denied: [String] = []
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
    /// The files the prompt being built sends; the conversation has seen them once its run is done.
    @ObservationIgnored private var sending: [DocKind: String] = [:]

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
        reparse(from: [:])
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

    private init(spec: Spec, documents: [DocKind: String], liveText: String, activity: [ActivityLine], isRunning: Bool, lastError: String?, conflict: DocKind?, snapshots: [DocKind: String], decisions: [Decision]) {
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
        reparse(from: [:])
    }

    var currentQuestion: Question? { spec.questions.first { $0.round == .intake && $0.answer == nil } }
    var answeredQuestions: [Question] { spec.questions.filter { $0.round == .intake && $0.answer != nil } }

    /// The heading the draft being written has reached ("2. Buy a class pack"), for the board's working line.
    var writingSection: String? {
        guard let start = liveText.range(of: "\n#", options: .backwards)?.upperBound ?? (liveText.hasPrefix("#") ? liveText.startIndex : nil) else { return nil }
        let line = liveText[start...].prefix { !$0.isNewline }.drop { $0 == "#" || $0 == " " }
        return line.isEmpty ? nil : String(line)
    }

    func summary(_ kind: DocKind) -> DocSummary { summaries[kind] ?? DocSummary() }

    /// Parses the files that changed since `old`.
    private func reparse(from old: [DocKind: String]) {
        let changed = Set(old.keys).union(documents.keys).filter { old[$0] != documents[$0] }
        for kind in changed {
            let text = documents[kind] ?? ""
            blocks[kind] = MarkdownParser.blocks(text)
            summaries[kind] = MarkdownParser.summary(text, kind: kind)
        }
        if changed.contains(.tasks) || changed.contains(.spec) {
            // A Quick fix has no TASKS.md: its build is one task, the fix SPEC.md describes.
            tasks = documents[.spec] != nil ? [SpecTask(number: 1, title: "the fix SPEC.md describes", priority: "", covers: [], reads: "SPEC.md", verify: "")] : SpecTask.parse(documents[.tasks] ?? "")
            steps = BuildStep.steps(tasks)
        }
        if changed.contains(.requirements) { stories = Story.parse(documents[.requirements] ?? "") }
        if changed.contains(.tasks) || changed.contains(.requirements) {
            var summary = summaries[.tasks] ?? MarkdownParser.summary("", kind: .tasks)
            summary.uncoveredCriteria = MarkdownParser.uncoveredCriteria(requirements: documents[.requirements] ?? "", tasks: documents[.tasks] ?? "")
            summaries[.tasks] = summary
        }
    }

    // MARK: - Intake

    /// One run returns every intake question at once. With none to ask, the board starts writing.
    func start() async {
        guard spec.stage == .discovery, !spec.questions.contains(where: { $0.round == .intake }) else { return }
        lastError = nil
        let end = await run(intakePrompt, step: .questions, resume: nil, persist: false, quick: true)
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

    /// Rename… in the sidebar: the name Mel shows. The folder keeps its slug, so paths in prompts,
    /// AGENTS.md and Git stay valid.
    func setName(_ name: String) {
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, name != spec.name else { return }
        spec.name = name
        persist()
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

    /// A text delta while drafting: the preview updates at most 5 times a second (each update parses and
    /// lays out the open file again), the file every 500 ms.
    private func received(_ text: String) {
        guard let kind = draftKind else { return }
        reply += text
        let now = ContinuousClock.now
        if now - shownAt >= .milliseconds(200) {
            shownAt = now
            liveText = DraftText.file(fromReply: reply, kind: kind)
        }
        if now - wroteAt >= .milliseconds(500) {
            wroteAt = now
            write(DraftText.file(fromReply: reply, kind: kind), for: kind)
        }
    }

    /// One agent run. Only one runs at a time across the app (`AppState.isAgentBusy`).
    private func run(_ prompt: String, step: TokenStep, resume: String?, persist persistSession: Bool, tools: Bool = true, quick: Bool = false, build: (task: Int, access: BuildAccess)? = nil) async -> RunEnd {
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
        // A build run uses the user's own default model, as their terminal would (OQ #42).
        let request = AgentRequest(prompt: prompt, workingDirectory: projectFolder, resumeSessionID: resume, persistSession: persistSession, allowsTools: tools,
                                   build: build?.access, model: build != nil ? nil : quick ? app.quickModel : app.writingModel)
        app.runningSpecID = spec.id
        self.runner = runner
        isRunning = true
        let task = Task { () -> RunEnd in
            var end = RunEnd.stopped(.crashed("Claude Code ended without a result."))
            do {
                loop: for try await event in runner.run(request) {
                    switch event {
                    case .session(let id) where build != nil:
                        spec.runs?[build!.task]?.session = id
                        persist()
                    case .session(let id) where persistSession:
                        if spec.conversation == nil { spec.conversation = Conversation(id: id) } else { spec.conversation?.id = id }
                        persist()
                    case .session, .rateLimit:
                        break
                    case .text(let text):
                        received(text)
                    case .step(let step):
                        activity.append(ActivityLine(at: .now, text: step))
                        // No --max-turns in Claude Code: a build run that loops is stopped here (OQ #42).
                        if build != nil, activity.count > Self.buildStepLimit {
                            await runner.stop()
                            end = .stopped(.crashed("Stopped after \(Self.buildStepLimit) steps without finishing."))
                            break loop
                        }
                    case .denied(let list):
                        denied += list
                    case .usage(let tokens):
                        spec.addTokens(tokens, to: step)
                        if let build {
                            let total = (spec.runs?[build.task]?.tokens ?? 0) + tokens
                            spec.runs?[build.task]?.tokens = total
                        }
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

    /// A run in the spec's conversation (drafts, changes, rewrites): resumed, so what it already
    /// holds comes from the prompt cache. Model and tools stay the same on every turn, since either
    /// change invalidates the cache. A lost conversation is dropped; the caller runs again without it.
    private func converse(_ prompt: String, step: TokenStep) async -> RunEnd {
        let sent = sending
        sending = [:]
        let end = await run(prompt, step: step, resume: spec.conversation?.id, persist: true)
        switch end {
        case .done(let reply):
            spec.conversation?.saw(sent)
            spec.conversation?.size += prompt.count + reply.count
        case .stopped(.sessionNotFound):
            spec.conversation = nil
        case .stopped, .refused:
            break
        }
        return end
    }

    /// A new conversation starts before one grows past `Conversation.limit`.
    private func trimConversation() {
        if let size = spec.conversation?.size, size > Conversation.limit { spec.conversation = nil }
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
        activity = []
        persist()
        let end = await converse(prompt, step: step)
        draftKind = nil
        liveText = ""
        return end
    }

    /// Writes `kind`, or continues it from its last complete section after a stop.
    private func draftOnBoard(_ kind: DocKind, fresh: Bool = false) async -> Bool {
        trimConversation()
        // A cut-off file continues in the conversation that was writing it.
        let partial = !fresh && spec.docs[kind] == .stopped && spec.conversation != nil ? DraftText.truncatedToLastCompleteSection(documents[kind] ?? "") : ""
        spec.begin(.draft(kind))
        if !partial.isEmpty {
            documents[kind] = partial
            write(partial, for: kind)
        }
        var values = promptValues(drafting: kind)
        if partial.isEmpty { values["approved"] = filesText(spec.size.files.prefix { $0 != kind }.filter(spec.written.contains)) }
        let prompt = partial.isEmpty
            ? Prompt(drafting: kind).build(values, fillGaps: spec.fillGaps, language: spec.language)
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
            spec.conversation?.saw([kind: final])
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
        /// Build (V2-13): tasks the change added, and tasks whose text it changed.
        var newTasks: Set<Int> = []
        var updatedTasks: Set<Int> = []
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
        guard !written.isEmpty else { return .refused }
        trimConversation()
        var values = promptValues(drafting: written[0])
        values["reading"] = attachments.isEmpty
            ? "Everything you need is in this conversation. Do not read files or call tools."
            : "You may open the attachments below with Read. Everything else you need is in this conversation."
        values["requests"] = requests.map { "- " + $0 }.joined(separator: "\n")
        values["attachments"] = attachments.isEmpty ? "(none)" : attachments.map { "- specs/\(slug)/.mel/attachments/\($0.fileName)" }.joined(separator: "\n")
        values["current"] = filesText(written)
        values["kinds"] = written.map { "`\($0.rawValue)`" }.joined(separator: ", ")
        let spent = spec.tokens?[.changes] ?? 0
        activity = []
        lastChange = nil
        let end = await converse(Prompt.change.build(values, fillGaps: spec.fillGaps, language: spec.language), step: .changes)
        switch end {
        case .done(let reply):
            // Edits that weren't put in place: the conversation's idea of these files is wrong now.
            guard let change = try? Change.decode(reply) else {
                spec.conversation?.forget(written)
                return .unreadable
            }
            let current = Dictionary(uniqueKeysWithValues: written.map { ($0, documents[$0] ?? "") })
            guard let texts = change.apply(to: current) else {
                spec.conversation?.forget(change.edits.map(\.file))
                spec.unplacedChange = UnplacedChange(request: requests.joined(separator: "\n"), change: change, files: change.unplaced(in: current), answers: answers)
                return .unplaced
            }
            install(texts, line: change.summary(order: written), passages: Dictionary(grouping: change.edits, by: \.file).mapValues { $0.map(\.new) }, spent: spent)
            return .applied
        case .stopped(.sessionNotFound):
            return await change(requests, attachments: attachments, answers: answers)
        case .stopped(let reason):
            return .stopped(reason)
        case .refused:
            return .refused
        }
    }

    /// Puts changed files in place (text, disk, snapshot), reruns Mel's own checks and sets the result line.
    private func install(_ texts: [DocKind: String], line: String, passages: [DocKind: [String]] = [:], spent: Int) {
        let oldTasks = Dictionary(tasks.map { ($0.number, $0) }) { first, _ in first }
        var before: [DocKind: String] = [:]
        for (kind, text) in texts {
            before[kind] = documents[kind]
            let final = text.trimmingCharacters(in: .whitespacesAndNewlines) + "\n"
            documents[kind] = final
            write(final, for: kind)
            saveSnapshot(kind)
            spec.conversation?.saw([kind: final])
        }
        refreshChecks()
        if spec.stage == .done { spec.retasked(tasks) }
        var result = ChangeResult(line: line, tokens: (spec.tokens?[.changes] ?? 0) - spent, passages: passages)
        result.before = before
        result.newTasks = Set(tasks.filter { oldTasks[$0.number] == nil }.map(\.number))
        result.updatedTasks = Set(tasks.filter { task in oldTasks[task.number].map { $0 != task } ?? false }.map(\.number))
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
    /// reason. On Build, `task` is where the request came from. False when the run didn't finish:
    /// the request stays in the box.
    @discardableResult
    func tell(_ text: String, files: [URL] = [], task: SpecTask? = nil) async -> Bool {
        let text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard spec.stage != .discovery, !isRunning, !text.isEmpty, !spec.written.isEmpty, spec.halted == nil, spec.unplacedChange == nil else { return false }
        let request = task.map { "Found while building task \($0.number) (\($0.title)): " + text } ?? text
        lastError = nil
        tellingTask = task?.number
        defer { tellingTask = nil }
        var attachments: [Attachment] = []
        if let store {
            for file in files { if let attachment = try? await store.attach(copying: file) { attachments.append(attachment) } }
            spec.attachments += attachments
        }
        let end = await change([request], attachments: attachments, answers: false)
        defer { persist() }
        switch end {
        case .applied:
            lastChange?.decision = addDecision(title: Self.title(text), reason: request, source: "Tell Mel")
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
        if spec.stage == .done { spec.retasked(tasks) }
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
        trimConversation()
        var values = promptValues(drafting: kind)
        values["file"] = kind.fileName
        values["instruction"] = unplaced.request
        values["current"] = filesText([kind])
        values["approved"] = filesText(spec.written.filter { $0 != kind })
        let spent = spec.tokens?[.changes] ?? 0
        let end = await stream(kind, prompt: Prompt.rewrite.build(values, fillGaps: spec.fillGaps, language: spec.language), step: .changes)
        if case .stopped(.sessionNotFound) = end {
            write(before, for: kind)
            return await rewriteUnplaced()
        }
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
        switch await run(Prompt.analyze.build(values, language: spec.language), step: .checks, resume: nil, persist: false, tools: false, quick: true) {
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
        spec.taskCount = tasks.count
        persist()
    }

    // MARK: - Build (V2-3)

    func status(of task: SpecTask) -> TaskStatus { spec.status(of: task, in: steps) }

    func prompt(of task: SpecTask) -> String { task.buildPrompt(slug: slug, of: tasks.count) }

    /// A Tell Mel change made the task differ from the prompt the user ran (V2-13).
    func promptChanged(_ task: SpecTask) -> Bool { spec.promptChanged(task.number, now: prompt(of: task)) }

    /// Copy prompt: the task's short prompt goes on the clipboard and the task is Running.
    func copyPrompt(of task: SpecTask) {
        SystemActions.copy(prompt(of: task))
        spec.started(task.number, prompt: prompt(of: task))
        uncommitted.remove(task.number)
        persist()
        // The commit to look for the task's own after; outside a repo there is none and nothing is checked.
        let folder = projectFolder
        Task {
            guard let head = await Task.detached(operation: { Git.head(at: folder) }).value else { return }
            spec.based(task.number, on: head)
            persist()
        }
    }

    /// Git has a commit with the task's `Mel-Task:` line since its prompt was copied. True when git
    /// can't tell (no repo, a run from before 0.7): only a known miss holds the task back.
    private func isCommitted(_ task: SpecTask) async -> Bool {
        guard let base = spec.runs?[task.number]?.base else { return true }
        let (trailer, folder) = (task.trailer(slug: slug), projectFolder)
        let found = await Task.detached { Git.hasCommit(with: trailer, since: base, in: folder) }.value
        if found == false { uncommitted.insert(task.number) } else { uncommitted.remove(task.number) }
        return found != false
    }

    /// Copy fix prompt: the failed check and its output; the task is Running again.
    func copyFixPrompt(of task: SpecTask) {
        guard case .failed(let output) = status(of: task) else { return }
        SystemActions.copy(task.fixPrompt(slug: slug, of: tasks.count, output: output))
        spec.started(task.number, prompt: prompt(of: task))
        persist()
    }

    /// Check it: Mel runs the task's verify command on this Mac. No agent, no tokens.
    func check(_ task: SpecTask) async {
        guard let app, !task.verify.isEmpty, !checking.contains(task.number), tellingTask != task.number else { return }
        checking.insert(task.number)
        guard await isCommitted(task) else {
            checking.remove(task.number)
            return
        }
        let result = await app.runCheck(task.verify, projectFolder)
        checking.remove(task.number)
        spec.finished(task.number, passed: result.passed, output: result.output, prompt: prompt(of: task), of: tasks)
        persist()
    }

    /// "Mark done without the check": only once the task's commit is there.
    func markDone(_ task: SpecTask) async {
        guard await isCommitted(task) else { return }
        spec.finished(task.number, passed: true, byHand: true, prompt: prompt(of: task), of: tasks)
        persist()
    }

    func reopen(_ task: SpecTask) {
        spec.reopen(task.number)
        persist()
    }

    /// "Start over" on the built banner: every task back to the start.
    func startOver() {
        spec.startOver()
        persist()
    }

    /// ‹ Plan: the board with the finished plan (V2-10).
    func reopenPlan() {
        spec.reopenPlan()
        persist()
    }

    // MARK: - Run in Mel (V2-17, OQ #39–42)

    static let buildStepLimit = 200
    /// `specs/<slug>` and the project context: Mel writes them, so they never block Run or go into a task's stash.
    private var melPaths: [String] { [String(spec.folder.path(percentEncoded: false).dropFirst(projectFolder.path(percentEncoded: false).count)).trimmingCharacters(in: ["/"]), ".mel"] }
    /// The spec's branch; every task commits to it (OQ #41).
    var branch: String { "mel/\(slug)" }

    /// Run: Claude Code builds the task in the background, allowed only its folders, its check and
    /// git commit. A stopped task goes on in the same session with its changes. When it ends, the
    /// report goes on the card, its decisions into DECISIONS.md, and Mel runs the check.
    func run(_ task: SpecTask, answer: String? = nil) async {
        guard runningTask == nil, let app, !app.isAgentBusy else { return }
        let (folder, excluded, branch) = (projectFolder, melPaths, branch)
        guard Git.isRepository(folder) else {
            lastError = "Run needs a git repository in \(folder.lastPathComponent). Copy prompt still works."
            return
        }
        let goesOn: Bool = switch status(of: task) { case .stopped, .asking: true; default: false }
        let resume = goesOn ? spec.runs?[task.number]?.session : nil
        if resume == nil {
            let files = await Task.detached { Git.uncommitted(in: folder, excluding: excluded) }.value ?? []
            guard files.isEmpty else {
                blockedRun = BlockedRun(task: task.number, files: files)
                return
            }
        }
        blockedRun = nil
        do {
            try await Task.detached { try Git.switchTo(branch: branch, in: folder) }.value
        } catch {
            lastError = "Couldn’t switch to \(branch): \(error.localizedDescription)"
            return
        }
        if resume == nil {
            spec.started(task.number, prompt: prompt(of: task))
            if let head = await Task.detached(operation: { Git.head(at: folder) }).value { spec.based(task.number, on: head) }
        } else {
            spec.runs?[task.number]?.state = .running
            spec.runs?[task.number]?.question = nil
        }
        uncommitted.remove(task.number)
        runningTask = task.number
        activity = []
        denied = []
        persist()
        let prompt = resume == nil ? task.runPrompt(slug: slug, of: tasks.count)
            : answer.map(task.answerPrompt) ?? "Go on with task \(task.number) from where you stopped; your changes are still there. End with the JSON object, as before."
        let access = BuildAccess(folders: task.changes, commands: task.verify.isEmpty ? [] : [task.verify])
        let end = await run(prompt, step: .build, resume: resume, persist: true, build: (task.number, access))
        runningTask = nil
        switch end {
        case .done(let reply) where BuildQuestion.parse(reply) != nil && BuildReport.parse(reply) == nil:
            // V2-18: it stops on a question; the answer goes on in the same session.
            spec.runs?[task.number]?.question = BuildQuestion.parse(reply)
            persist()
            app.notify("Task \(task.number) asks a question", spec.name, nil)
        case .done(let reply):
            var report = BuildReport.parse(reply) ?? BuildReport(works: [], notDone: ["Claude Code didn’t say what it did. Show the changed files to see."])
            if report.refused.isEmpty { report.refused = denied }
            spec.runs?[task.number]?.report = report
            for decision in report.decisions {
                _ = addDecision(title: decision.title, reason: decision.why + (decision.instead.isEmpty ? "" : " Instead: \(decision.instead)"), source: "Task \(task.number), while building")
            }
            persist()
            if task.verify.isEmpty { await markDone(task) } else { await check(task) }
        case .stopped(let reason):
            spec.runs?[task.number]?.state = .stopped
            if reason != .user { lastError = Self.message(reason) }
            persist()
        case .refused:
            spec.runs?[task.number] = nil
            persist()
        }
    }

    /// V2-18: the user's answer goes into DECISIONS.md, then the task goes on where it stopped.
    func answer(_ task: SpecTask, with answer: String) async {
        guard case .asking(let question) = status(of: task), !answer.isEmpty else { return }
        _ = addDecision(title: question.title, reason: answer, source: "Task \(task.number) asked while building")
        await run(task, answer: answer)
    }

    /// V2-20: "Commit them, then run" or "Put them aside, then run".
    func clearBlockedRun(commit: Bool) async {
        guard let blocked = blockedRun, let task = tasks.first(where: { $0.number == blocked.task }) else { return }
        let (folder, excluded, number) = (projectFolder, melPaths, task.number)
        do {
            try await Task.detached {
                if commit { try Git.commitAll(message: "chore: my changes before Mel’s task \(number)", excluding: excluded, in: folder) }
                else { try Git.stash(message: "Mel: before task \(number)", excluding: excluded, in: folder) }
            }.value
        } catch {
            lastError = error.localizedDescription
            return
        }
        blockedRun = nil
        await run(task)
    }

    func cancelBlockedRun() { blockedRun = nil }

    /// V2-21 Undo: the stopped task's changes go into a stash (never deleted) and it is ready again.
    func undoStopped(_ task: SpecTask) async {
        let (folder, excluded, number) = (projectFolder, melPaths, task.number)
        do {
            try await Task.detached { try Git.stash(message: "Mel: undone task \(number)", excluding: excluded, in: folder) }.value
        } catch {
            lastError = error.localizedDescription
            return
        }
        spec.runs?[task.number] = nil
        persist()
    }

    /// "Open Terminal here": Claude Code in the project, ready for a pasted prompt.
    func openTerminal() {
        do { try SystemActions.openInTerminal(command: "claude", in: projectFolder) } catch { lastError = error.localizedDescription }
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

    func showInFinder() { SystemActions.showInFinder(spec.folder) }

    /// The sidebar's Building and Done groups; Mel can't see the coding agent, so the user moves a spec on.
    func setBuild(_ state: BuildState?) {
        guard spec.stage == .done else { return }
        spec.build = state
        persist()
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

    /// The values every prompt shares. In a running conversation the project context and the idea
    /// are already in it.
    private func promptValues(drafting kind: DocKind) -> [String: String] {
        let project = app?.contexts[Project(folder: spec.project).id]?.promptText
        let attachments = spec.attachments.map { "- specs/\(slug)/.mel/attachments/\($0.fileName)" }
        let held = spec.conversation == nil ? nil : "(earlier in this conversation)"
        return ["name": spec.name, "idea": held ?? spec.idea, "files": spec.size.filesText,
                "project": held ?? project ?? "(no project context yet)",
                "attachments": attachments.isEmpty ? "(none)" : attachments.joined(separator: "\n"),
                "answers": spec.answersText, "decide": spec.decideText, "steps": kind.stepsText]
    }

    /// The files of `kinds` for a conversation prompt: the text of those it hasn't seen as they are
    /// now, and the names of the rest.
    private func filesText(_ kinds: [DocKind]) -> String {
        let unseen = spec.conversation?.unseen(kinds, in: documents) ?? kinds
        for kind in unseen { sending[kind] = documents[kind] ?? "" }
        let held = kinds.filter { !unseen.contains($0) }
        guard !held.isEmpty else { return text(of: unseen) }
        let note = "Unchanged since you last saw them in this conversation, with the edits you sent since applied: \(held.map(\.fileName).joined(separator: ", "))."
        return unseen.isEmpty ? note : text(of: unseen) + "\n\n" + note
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

    static func preview(_ spec: Spec, documents: [DocKind: String] = [:], liveText: String = "", activity: [ActivityLine] = [], isRunning: Bool = false, lastError: String? = nil, conflict: DocKind? = nil, snapshots: [DocKind: String] = [:], decisions: [Decision] = [], lastChange: ChangeResult? = nil, tellingTask: Int? = nil, runningTask: Int? = nil, blockedRun: BlockedRun? = nil) -> SpecSession {
        let session = SpecSession(spec: spec, documents: documents, liveText: liveText, activity: activity, isRunning: isRunning, lastError: lastError, conflict: conflict, snapshots: snapshots, decisions: decisions)
        session.lastChange = lastChange
        session.tellingTask = tellingTask
        session.runningTask = runningTask
        session.blockedRun = blockedRun
        return session
    }
}

private extension Question {
    func with(id: String) -> Question {
        Question(id: id, title: title, why: why, shapes: shapes, round: round, options: options, answer: answer, about: about)
    }
}
