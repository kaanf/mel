import Foundation

/// One thing Mel needs from the user (FLOW.md › V2 "One inbox"): an intake question, a question
/// a draft asked, an open question a draft left in its file, or an issue the check found. All
/// are answered the same way: with an option, or with anything typed.
public struct Card: Identifiable, Hashable, Sendable {
    public var id: String
    /// The written file it is about. Nil for an intake question and for a check issue.
    public var file: DocKind?
    /// "REQUIREMENTS.md · about cancelling".
    public var location: String
    public var text: String
    public var why: String
    public var options: [Option]
    /// A contradiction: the red "These disagree" card.
    public var disagrees: Bool
    public var answer: Answer?
    /// What "Write it now" settles on: the suggested option, or an issue's primary action.
    public var guess: String
    /// "Cancelling": what the question is about, shown over it (V2-29). Empty when the agent named none.
    public var topic: String

    public init(_ question: Question) {
        id = question.id
        file = question.round == .intake ? nil : question.shapes
        location = question.round == .intake ? "" : question.shapes.fileName + (question.about.map { " · about \($0)" } ?? "")
        text = question.title
        why = question.why
        options = question.options
        disagrees = false
        answer = question.answer
        guess = (question.options.first(where: \.suggested) ?? question.options.first)?.label ?? ""
        topic = question.about.map { $0.prefix(1).uppercased() + $0.dropFirst() } ?? ""
    }

    public init(_ issue: AnalyzeResult.Issue) {
        id = "issue-\(issue.id)"
        file = nil
        location = issue.location
        text = issue.text
        why = ""
        // The note says where the answer lands: the source tile of a contradiction (V2-29).
        options = issue.actions.map { Option(label: $0.label, note: $0.files.isEmpty ? "" : "Changes " + $0.files.map(\.fileName).joined(separator: ", ")) }
        disagrees = issue.kind == .contradiction
        answer = issue.answer
        guess = issue.actions.last?.label ?? ""
        topic = issue.kind == .contradiction ? "These disagree" : "Mel’s check"
    }

    /// What an answered card shows; nil while it is open.
    public var answerText: String? {
        switch answer {
        case nil: nil
        case .agentDecides: guess.isEmpty ? "Mel decided" : "Mel guessed: \(guess)"
        case .option(let i, let note): (options.indices.contains(i) ? options[i].label : "?") + (note.map { " (\($0))" } ?? "")
        case .text(let text): text
        }
    }
}

/// What the board does next without the user.
public enum BoardStep: Hashable, Sendable {
    /// Write the next file, or continue the one that was cut off.
    case draft(DocKind)
    /// One patch run for every answer given since the files were written.
    case change
    /// After the last file: look for contradictions.
    case check
}

/// The four file states the board shows. Stopped and out-of-date files are `needsYou`.
public enum FileState: Hashable, Sendable { case ready, writing, needsYou, waiting }

// The board's pipeline (V2.md §0). No review and no approval: a file is written, its cards are
// answered, the answers go in as one patch run, the next file starts. `nextStep` says what to
// run; the functions below record what happened.
extension Spec {
    /// Files with a finished draft, in order.
    public var written: [DocKind] { size.files.filter { [.review, .approved, .edited, .stale].contains(docs[$0]) } }

    /// The intake question being asked: one at a time, before any file.
    public var intakeCard: Card? {
        guard stage == .discovery else { return nil }
        return questions.first { $0.round == .intake && $0.answer == nil }.map(Card.init)
    }

    /// The inbox: the questions of each written file in file order, then the check's issues.
    public var cards: [Card] {
        let asked = written.flatMap { kind in questions.filter { $0.round != .intake && $0.shapes == kind } }
        return asked.map(Card.init) + (analysis?.issues ?? []).map(Card.init)
    }

    public var openCards: [Card] { cards.filter { $0.answer == nil } }

    /// Answers waiting for a change run, as its requests.
    public var changeRequests: [String] {
        let answers = questions.filter { $0.pending == true }.compactMap { q -> String? in
            guard let answer = q.answerText else { return nil }
            switch q.round {
            case .intake: return "The answer to “\(q.title)” is now: \(answer) Change every file it affects."
            case .draft: return "\(q.shapes.fileName) asked “\(q.title)”. The answer: \(answer)"
            case .open: return "\(q.shapes.fileName) has the open question “\(q.title)”. The answer: \(answer) Remove its callout."
            }
        }
        let fixes = (analysis?.issues ?? []).filter { $0.pending == true }.compactMap { issue -> String? in
            switch issue.answer {
            case nil: nil
            case .option(let i, _): issue.actions.indices.contains(i) ? issue.actions[i].fix : nil
            case .agentDecides: issue.actions.last?.fix
            case .text(let text): "\(issue.location): \(issue.text) The user says: \(text)"
            }
        }
        return answers + fixes
    }

    /// Nil while it waits for the user: open cards, an edit to settle, an unplaced change, a stop.
    public var nextStep: BoardStep? {
        guard stage == .board, halted == nil, unplacedChange == nil, !hasPendingEdit, openCards.isEmpty else { return nil }
        if !changeRequests.isEmpty { return .change }
        if let next = size.files.first(where: { [.locked, .writing, .stopped].contains(docs[$0]) }) { return .draft(next) }
        // `.running` here is a check the app quit in the middle of.
        if size.hasAnalyze, analyze == .locked || analyze == .running { return .check }
        return nil
    }

    /// "ARCHITECTURE.md starts after 2 answers": the next file and the cards it waits for.
    public var gate: (file: DocKind, answers: Int)? {
        guard stage == .board, !openCards.isEmpty, let next = size.files.first(where: { docs[$0] == .locked }) else { return nil }
        return (next, openCards.count)
    }

    public func fileState(_ kind: DocKind) -> FileState {
        switch docs[kind] ?? .locked {
        case .locked: .waiting
        case .writing: .writing
        case .stopped, .edited, .stale: .needsYou
        case .review, .approved: openCards.contains { $0.file == kind } ? .needsYou : .ready
        }
    }

    /// "Plan is ready": everything is written, answered and applied. A check that failed doesn't block it.
    public var isReady: Bool {
        stage == .board && halted == nil && unplacedChange == nil && !hasPendingEdit && openCards.isEmpty && changeRequests.isEmpty
            && written == size.files && (!size.hasAnalyze || (analyze != .locked && analyze != .running))
    }

    private var hasPendingEdit: Bool { docs.values.contains { $0 == .edited || $0 == .stale } }

    // MARK: Answers

    /// Every intake question is answered, or "Skip, write the plan now": the rest become guesses.
    public mutating func startBoard() {
        guard stage == .discovery else { return }
        for i in questions.indices where questions[i].round == .intake && questions[i].answer == nil { questions[i].answer = .agentDecides }
        stage = .board
    }

    /// Answers a card, or changes its answer. Once the card's file is written the answer waits
    /// for the next change run; a guess doesn't, because the draft already stands on one.
    public mutating func answer(card id: String, _ answer: Answer) {
        if let i = questions.firstIndex(where: { $0.id == id }) {
            let reaches = questions[i].round == .intake ? !written.isEmpty : written.contains(questions[i].shapes)
            questions[i].answer = answer
            questions[i].pending = stage == .board && reaches && answer != .agentDecides ? true : nil
        } else if let i = analysis?.issues.firstIndex(where: { "issue-\($0.id)" == id }) {
            analysis?.issues[i].answer = answer
            analysis?.issues[i].pending = true
            countIssues()
        }
    }

    /// Change on an answered card: it is open again and nothing is waiting for it.
    public mutating func reopen(card id: String) {
        if let i = questions.firstIndex(where: { $0.id == id }) {
            questions[i].answer = nil
            questions[i].pending = nil
        } else if let i = analysis?.issues.firstIndex(where: { "issue-\($0.id)" == id }) {
            analysis?.issues[i].answer = nil
            analysis?.issues[i].pending = nil
            countIssues()
        }
    }

    /// "Write it now": the open questions become guesses, so the next file starts.
    public mutating func writeNow() {
        for card in openCards where card.file != nil { answer(card: card.id, .agentDecides) }
    }

    // MARK: Runs

    public mutating func begin(_ step: BoardStep) {
        switch step {
        case .draft(let kind): docs[kind] = .writing
        case .check: analyze = .running
        case .change: break
        }
    }

    /// `kind` is written (first draft or whole rewrite). `asked` replaces its unanswered questions:
    /// the trailer's and one per `[!OPEN QUESTION]` callout.
    public mutating func drafted(_ kind: DocKind, asked: [Question]) {
        docs[kind] = .approved
        questions.removeAll { $0.round != .intake && $0.shapes == kind && $0.answer == nil }
        questions += asked.filter { new in !questions.contains { $0.id == new.id } }
    }

    /// The change run's edits are in the files.
    public mutating func changed() {
        for i in questions.indices { questions[i].pending = nil }
        for i in analysis?.issues.indices ?? 0..<0 { analysis?.issues[i].pending = nil }
    }

    public mutating func checked(_ result: AnalyzeResult) {
        analysis = result
        countIssues()
    }

    /// The reply couldn't be read. The board goes on; "Check again" runs it later.
    public mutating func checkFailed() {
        analyze = .stale
    }

    /// The agent stopped during `step`. A cut-off draft keeps its file; a check runs again on resume.
    public mutating func halt(_ reason: StopReason, during step: BoardStep) {
        switch step {
        case .draft(let kind):
            docs[kind] = .stopped
            halted = Halt(reason: reason, file: kind)
        case .check:
            analyze = .locked
            halted = Halt(reason: reason)
        case .change:
            halted = Halt(reason: reason)
        }
    }

    public mutating func resume() {
        halted = nil
    }

    /// "Finish it myself": the cut-off file counts as written.
    public mutating func finishByHand() {
        if let file = halted?.file { docs[file] = .approved }
        halted = nil
    }

    // MARK: Edits by hand

    /// The user saved an edit to a written file: the files built on it wait for Update or Keep.
    @discardableResult
    public mutating func editedOnBoard(_ kind: DocKind) -> Bool {
        guard stage == .board, docs[kind] == .approved || docs[kind] == .review else { return false }
        docs[kind] = .edited
        for later in size.files.drop(while: { $0 != kind }).dropFirst() where docs[later] == .approved || docs[later] == .review { docs[later] = .stale }
        return true
    }

    /// The files built on an edited file.
    public var builtOnEdit: [DocKind] { size.files.filter { docs[$0] == .stale } }

    /// "Keep them as they are", and the end of Update and Undo: nothing waits any more.
    public mutating func settleEdit() {
        for kind in size.files where docs[kind] == .edited || docs[kind] == .stale { docs[kind] = .approved }
    }

    // MARK: Ready

    /// "Start Building".
    @discardableResult
    public mutating func startBuilding() -> Bool {
        guard isReady else { return false }
        stage = .done
        return true
    }

    /// V2-3's ‹ Plan: back to the board with the plan ready (V2-10). Task runs stay; Start Building returns.
    public mutating func reopenPlan() {
        guard stage == .done else { return }
        stage = .board
    }

    private mutating func countIssues() {
        let open = analysis?.issues.count { $0.answer == nil } ?? 0
        analyze = open == 0 ? .passed : .issues(open)
    }
}

extension Question {
    /// The card for an `[!OPEN QUESTION]` callout: no options, so it takes a typed answer.
    public init(_ open: OpenQuestion) {
        self.init(id: "\(open.kind.rawValue)-open-\(open.index)", title: open.text, why: "", shapes: open.kind, round: .open, options: [])
    }
}
