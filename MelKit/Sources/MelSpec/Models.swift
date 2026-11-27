import Foundation

public struct Spec: Codable, Identifiable, Hashable, Sendable {
    public let id: UUID
    public var name: String
    public var idea: String
    public var size: SpecSize
    /// `<project>/specs/<slug>/`, the folder that holds the size's files.
    public var folder: URL
    public var stage: Stage
    public var docs: [DocKind: DocStatus]
    public var questions: [Question]
    public var coverage: [CoverageItem]
    public var attachments: [Attachment]
    public var analyze: AnalyzeStatus
    public var analysis: AnalyzeResult?
    /// B1 "Let Mel fill small gaps". Off: no assumptions; gaps become open questions.
    public var fillGaps: Bool
    /// What the agent writes in (A1, Settings); nil for specs made before 0.4, written in the idea's language.
    public var language: SpecLanguage?
    /// Board: the agent stopped; nothing runs until the user resumes.
    public var halted: Halt?
    /// Board: a change that couldn't be placed, waiting for "Rewrite FILE" or Cancel.
    public var unplacedChange: UnplacedChange?
    /// Board: stories the user removed, kept so DECISIONS.md can offer Restore.
    public var removedStories: [RemovedStory]?
    /// Tokens used per step, from each run's `result.usage` (OQ #26); nil before the first counted run.
    public var tokens: [TokenStep: Int]?
    /// After "Build with Claude Code": the sidebar's Building and Done groups. Nil while it is planned.
    public var build: BuildState?
    /// The main model's conversation for this spec; nil until its first draft starts one.
    public var conversation: Conversation?

    /// A new spec starts with the intake questions and every file of its size waiting.
    public init(id: UUID = UUID(), name: String, idea: String, size: SpecSize = .product, folder: URL, stage: Stage = .discovery, docs: [DocKind: DocStatus]? = nil, questions: [Question] = [], coverage: [CoverageItem] = [], attachments: [Attachment] = [], analyze: AnalyzeStatus = .locked, analysis: AnalyzeResult? = nil, fillGaps: Bool = true, language: SpecLanguage? = nil) {
        self.id = id
        self.name = name
        self.idea = idea
        self.size = size
        self.folder = folder
        self.stage = stage
        self.docs = docs ?? size.allLocked
        self.questions = questions
        self.coverage = coverage
        self.attachments = attachments
        self.analyze = analyze
        self.analysis = analysis
        self.fillGaps = fillGaps
        self.language = language
    }

    /// The project folder: `folder` is `<project>/specs/<slug>/`.
    public var project: URL { folder.deletingLastPathComponent().deletingLastPathComponent().normalizedFolder }

    /// A new spec's name until the intake names it.
    public static let untitledName = "Untitled Spec"
}

/// Where a spec is once its plan is handed to the coding agent. Mel can't see the agent work:
/// the user marks it done.
public enum BuildState: String, Codable, Hashable, Sendable { case building, done }

/// The language Mel asks the agent to write a spec in. The app's UI stays English.
public enum SpecLanguage: String, Codable, CaseIterable, Hashable, Sendable {
    case english, turkish

    /// The language's own name, for the picker.
    public var name: String {
        switch self {
        case .english: "English"
        case .turkish: "Türkçe"
        }
    }

    /// The language's English name, for `language.md`.
    public var promptName: String { rawValue.capitalized }
}

/// V2.md §4. The size fixes the files and their order.
public enum SpecSize: String, Codable, CaseIterable, Hashable, Sendable {
    case quickFix, feature, product

    public var files: [DocKind] {
        switch self {
        case .quickFix: [.spec]
        case .feature: [.requirements, .architecture, .tasks]
        case .product: [.product, .requirements, .experience, .architecture, .tasks]
        }
    }

    /// Round-1 questions the intake asks for (1–2, about 3, about 5).
    public var intakeQuestions: Int {
        switch self {
        case .quickFix: 2
        case .feature: 3
        case .product: 5
        }
    }

    /// The intake's starting topics. Those no question covers are left for the drafts to settle.
    public var topics: [String] {
        switch self {
        case .quickFix: ["What breaks today", "Expected behavior", "How to verify"]
        case .feature: ["Goal", "Existing code it touches", "Edge cases", "Out of scope"]
        case .product: ["Goal and success metric", "Users and roles", "Platforms", "Privacy and offline", "Out of scope"]
        }
    }

    /// Quick fix has one file: nothing to check against.
    public var hasAnalyze: Bool { self != .quickFix }

    /// Only a new product works without a project: it gets a new folder.
    public var needsProject: Bool { self != .product }

    /// V2-1's guess from the user's words (OQ #27): a bug is a Quick fix, a new app a New
    /// product, anything else a Feature. Without a project it is always a New product.
    public static func guess(from idea: String, hasProject: Bool) -> SpecSize {
        guard hasProject else { return .product }
        let text = idea.lowercased()
        if text.contains(/bug|crash|broken|wrong|double|fails|error|fix/) { return .quickFix }
        if text.contains(/an app|new app|a platform|for my|from scratch|website for/) { return .product }
        return .feature
    }

    /// The file drafted after `kind`, or nil after the last one.
    public func file(after kind: DocKind) -> DocKind? {
        guard let i = files.firstIndex(of: kind), i + 1 < files.count else { return nil }
        return files[i + 1]
    }

    public var allLocked: [DocKind: DocStatus] { Dictionary(uniqueKeysWithValues: files.map { ($0, .locked) }) }
}

public enum DocKind: String, Codable, CodingKeyRepresentable, CaseIterable, Hashable, Sendable {
    case product, requirements, experience, architecture, tasks, spec

    public var fileName: String { rawValue.uppercased() + ".md" }
    public var title: String { rawValue.capitalized }

    /// What a draft of this file works through, listed in its prompt under "Steps".
    public var draftSteps: [String] {
        switch self {
        case .product: ["Read the idea and your answers", "Describe the problem and the goal", "Name the users and roles", "Set the scope and what is out of scope", "Define how success is measured", "Mark anything you didn’t confirm as an assumption"]
        case .requirements: ["Read the approved files and your answers", "Write the stories with acceptance criteria", "Set priority P1 to P3 and mark the MVP line", "Add quality needs: privacy, speed, offline", "List edge cases for every P1 story", "Mark anything you didn’t confirm as an assumption", "Check that every criterion can be tested"]
        case .experience: ["Read the approved files and your answers", "Map each flow and the criteria it covers", "List every screen with its states", "Flag states that are missing", "Set the visual direction", "Mark anything you didn’t confirm as an assumption"]
        case .architecture: ["Read the approved files and the project context", "Lay out the modules and their boundaries", "Describe the data", "Describe the API and integrations", "Record the key decisions with reasons", "Mark anything you didn’t confirm as an assumption"]
        case .tasks: ["Read the approved files", "Break the work into tasks", "Link each task to the criteria it covers", "Add what each task reads and how to verify it", "Mark tasks that can run in parallel", "Check that every P1 criterion has a task"]
        case .spec: ["Read the report and the code it touches", "Describe what breaks", "Describe the expected behavior", "Write how to verify the fix", "List the code it touches", "Set what is out of scope"]
        }
    }
}

public enum Stage: Codable, Hashable, Sendable {
    /// The intake questions, before any file.
    case discovery
    /// The board (Board.swift): files are written one at a time between the user's answers.
    case board
    /// After "Start Building".
    case done

    /// A spec from before 0.5 that was drafting, in review, stopped or in Analyze opens on the board.
    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self = c.contains(.discovery) ? .discovery : c.contains(.done) ? .done : .board
    }
}

/// `approved`: written (`review` in specs from before 0.5 means the same). `edited`: the user
/// changed a written file; `stale`: a file built on an edited one.
public enum DocStatus: String, Codable, Hashable, Sendable { case locked, writing, stopped, review, approved, edited, stale }

/// The check after the last file: not run yet, running, n open issues, passed, or `stale` when its reply couldn't be read.
public enum AnalyzeStatus: Codable, Hashable, Sendable {
    case locked
    case running
    case issues(Int)
    case passed
    case stale
}

/// Round 1 comes from the intake; round 2 from a draft's `<!-- mel:questions -->` trailer; `open`
/// is an `[!OPEN QUESTION]` callout a draft left in its file (board only).
public enum QuestionRound: Int, Codable, Hashable, Sendable { case intake = 1, draft = 2, open = 3 }

/// Why the board's agent stopped. `file` is the draft it cut off, kept as far as it got.
public struct Halt: Codable, Hashable, Sendable {
    public var reason: StopReason
    public var file: DocKind?

    public init(reason: StopReason, file: DocKind? = nil) {
        self.reason = reason
        self.file = file
    }
}

/// A story cut from REQUIREMENTS.md with Remove: its section as it was, for Restore.
public struct RemovedStory: Codable, Identifiable, Hashable, Sendable {
    public var id: String
    public var title: String
    public var section: String

    public init(id: String, title: String, section: String) {
        self.id = id
        self.title = title
        self.section = section
    }
}

/// A change run whose edits couldn't all be placed (OQ #25). Nothing was changed: `files` are
/// offered for a whole rewrite one by one, `change` holds the edits for the other files.
public struct UnplacedChange: Codable, Hashable, Sendable {
    public var request: String
    public var change: Change
    public var files: [DocKind]
    /// The run was for card answers (`Spec.changeRequests`), not a request the user typed.
    public var answers: Bool

    public init(request: String, change: Change, files: [DocKind], answers: Bool = false) {
        self.request = request
        self.change = change
        self.files = files
        self.answers = answers
    }
}

/// A file copied into `specs/<slug>/.mel/attachments/` (B1 Add Files, drop, Paste Log).
public struct Attachment: Codable, Identifiable, Hashable, Sendable {
    public var fileName: String
    public var id: String { fileName }

    public init(fileName: String) { self.fileName = fileName }
}

public struct Question: Codable, Identifiable, Hashable, Sendable {
    public let id: String
    public var title: String
    public var why: String
    /// Round 1: the file it shapes. Round 2: the file whose draft asked it, revised on answer.
    public var shapes: DocKind
    public var round: QuestionRound
    public var options: [Option]
    public var answer: Answer?
    /// The topic in two or three words, for a card's "REQUIREMENTS.md · about cancelling".
    public var about: String?
    /// Board: answered after its file was written; the next change run applies it.
    public var pending: Bool?

    public init(id: String, title: String, why: String, shapes: DocKind, round: QuestionRound = .intake, options: [Option], answer: Answer? = nil, about: String? = nil) {
        self.id = id
        self.title = title
        self.why = why
        self.shapes = shapes
        self.round = round
        self.options = options
        self.answer = answer
        self.about = about
    }
}

public struct Option: Codable, Hashable, Sendable {
    public var label: String
    public var note: String
    public var suggested: Bool

    public init(label: String, note: String, suggested: Bool = false) {
        self.label = label
        self.note = note
        self.suggested = suggested
    }
}

public enum Answer: Codable, Hashable, Sendable {
    case option(Int, note: String?)
    case agentDecides
    case text(String)
}

public struct CoverageItem: Codable, Hashable, Sendable {
    public var label: String
    public var phase: DocKind
    public var state: CoverageState
    /// The intake question that asks about it; answering it makes the topic covered.
    public var question: String?

    public init(label: String, phase: DocKind = .product, state: CoverageState, question: String? = nil) {
        self.label = label
        self.phase = phase
        self.state = state
        self.question = question
    }

    /// state.json from before phased Discovery has no `phase`; those topics load as `.product`.
    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        label = try c.decode(String.self, forKey: .label)
        phase = try c.decodeIfPresent(DocKind.self, forKey: .phase) ?? .product
        state = try c.decode(CoverageState.self, forKey: .state)
        question = try c.decodeIfPresent(String.self, forKey: .question)
    }
}

/// `later`: the intake leaves the topic to the draft, which asks it as a round-2 question.
public enum CoverageState: String, Codable, Hashable, Sendable { case covered, asking, notYet, later }

public enum StopReason: Codable, Hashable, Sendable {
    case user
    case usageLimit(resetsAt: Date?)
    case signedOut
    case crashed(String)
    case timeout
    case sessionNotFound              // --resume id unknown: SpecSession reruns fresh, never shown to the user
}

public struct ActivityLine: Hashable, Identifiable, Sendable {
    public let id = UUID()
    public var at: Date
    public var text: String

    public init(at: Date, text: String) {
        self.at = at
        self.text = text
    }
}

public enum AgentStatus: Hashable, Sendable {
    case checking
    case ready(executable: URL, version: String)
    case notSignedIn(executable: URL)
    case missing
    case broken(String)
}
