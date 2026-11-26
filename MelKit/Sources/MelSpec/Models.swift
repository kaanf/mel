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
    /// B1 "Builds on" chips (Feature): module names from `structure.md`, or "Something new".
    public var buildsOn: [String]
    public var attachments: [Attachment]
    public var analyze: AnalyzeStatus
    public var analysis: AnalyzeResult?
    /// B1 "Let Mel fill small gaps". Off: no assumptions; gaps become open questions.
    public var fillGaps: Bool
    /// What the agent writes in (A1, Settings); nil for specs made before 0.4, written in the idea's language.
    public var language: SpecLanguage?
    /// Files waiting for a revise run, in order (analyze fixes, refine).
    public var queue: [DocKind]
    /// The pending revise instruction per file (an answer, an analyze fix, a refine); cleared when its revise ends.
    public var instructions: [DocKind: String]
    /// The file "Rewrite FILE" is writing whole, until that run ends.
    public var rewriting: DocKind?
    /// Board: the agent stopped; nothing runs until the user resumes.
    public var halted: Halt?
    /// Board: a change that couldn't be placed, waiting for "Rewrite FILE" or Cancel.
    public var unplacedChange: UnplacedChange?
    /// Tokens used per step, from each run's `result.usage` (OQ #26); nil before the first counted run.
    public var tokens: [TokenStep: Int]?
    public var sessionID: String?

    /// A new spec starts in Discovery with every file of its size locked.
    public init(id: UUID = UUID(), name: String, idea: String, size: SpecSize = .product, folder: URL, stage: Stage = .discovery, docs: [DocKind: DocStatus]? = nil, questions: [Question] = [], coverage: [CoverageItem] = [], buildsOn: [String] = [], attachments: [Attachment] = [], analyze: AnalyzeStatus = .locked, analysis: AnalyzeResult? = nil, fillGaps: Bool = true, language: SpecLanguage? = nil, queue: [DocKind] = [], instructions: [DocKind: String] = [:], sessionID: String? = nil) {
        self.id = id
        self.name = name
        self.idea = idea
        self.size = size
        self.folder = folder
        self.stage = stage
        self.docs = docs ?? size.allLocked
        self.questions = questions
        self.coverage = coverage
        self.buildsOn = buildsOn
        self.attachments = attachments
        self.analyze = analyze
        self.analysis = analysis
        self.fillGaps = fillGaps
        self.language = language
        self.queue = queue
        self.instructions = instructions
        self.sessionID = sessionID
    }

    /// The project folder: `folder` is `<project>/specs/<slug>/`.
    public var project: URL { folder.deletingLastPathComponent().deletingLastPathComponent().normalizedFolder }

    /// B1's name when the user types none; intake then names the spec.
    public static let untitledName = "Untitled Spec"

    /// Files whose revise reply couldn't be placed: nothing changed, the instruction waits for
    /// "Rewrite FILE" or Cancel (OQ #25).
    public var unplaced: [DocKind] { size.files.filter { instructions[$0] != nil && docs[$0] == .review && !queue.contains($0) } }

    /// C1: approved files a user edit made out of date, waiting for Refine or Keep.
    public var outOfDate: [DocKind] { size.files.filter { docs[$0] == .stale } }
}

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

    /// B1 "Mel will ask about" chips; also the intake's starting coverage list.
    public var topics: [String] {
        switch self {
        case .quickFix: ["What breaks today", "Expected behavior", "How to verify"]
        case .feature: ["Goal", "Existing code it touches", "Edge cases", "Out of scope"]
        case .product: ["Goal and success metric", "Users and roles", "Platforms", "Privacy and offline", "Out of scope"]
        }
    }

    /// Quick fix goes straight to Spec ready.
    public var hasAnalyze: Bool { self != .quickFix }

    /// Only Product works without a project (A4x).
    public var needsProject: Bool { self != .product }

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

    /// B3's checklist, fixed in the prompt; the agent emits `<!-- mel:step N -->` as it reaches step N.
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
    case discovery
    /// The V2 board (Board.swift): files are written one at a time between the user's answers.
    /// It replaces `drafting`, `review`, `stopped` and `analyze`, which go with the lane A–C views.
    case board
    case drafting(DocKind)
    case review(DocKind)
    case stopped(DocKind, StopReason)
    /// B6: the analyze run, or its result waiting for Fix / Hand Off Anyway.
    case analyze
    case done
}

/// V2.md §7. `edited`: the user changed an approved file; `stale`: a file after an edited one ("Out of date").
public enum DocStatus: String, Codable, Hashable, Sendable { case locked, writing, stopped, review, approved, edited, stale }

/// The sidebar's Analyze row: Queued / Locked, running, n issues, Passed, Rerun (stale).
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

/// A change run whose edits couldn't all be placed (OQ #25). Nothing was changed: `files` are
/// offered for a whole rewrite one by one, `change` holds the edits for the other files.
public struct UnplacedChange: Codable, Hashable, Sendable {
    public var request: String
    public var change: Change
    public var files: [DocKind]

    public init(request: String, change: Change, files: [DocKind]) {
        self.request = request
        self.change = change
        self.files = files
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
