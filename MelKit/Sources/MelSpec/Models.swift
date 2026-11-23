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
    /// Files waiting for a revise run, in order (analyze fixes, refine).
    public var queue: [DocKind]
    public var sessionID: String?

    /// A new spec starts in Discovery with every file of its size locked.
    public init(id: UUID = UUID(), name: String, idea: String, size: SpecSize = .product, folder: URL, stage: Stage = .discovery, docs: [DocKind: DocStatus]? = nil, questions: [Question] = [], coverage: [CoverageItem] = [], buildsOn: [String] = [], attachments: [Attachment] = [], analyze: AnalyzeStatus = .locked, analysis: AnalyzeResult? = nil, fillGaps: Bool = true, queue: [DocKind] = [], sessionID: String? = nil) {
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
        self.queue = queue
        self.sessionID = sessionID
    }

    /// The project folder: `folder` is `<project>/specs/<slug>/`.
    public var project: URL { folder.deletingLastPathComponent().deletingLastPathComponent().normalizedFolder }
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

/// Round 1 comes from the intake; round 2 from a draft's `<!-- mel:questions -->` trailer (B4 "Before you approve").
public enum QuestionRound: Int, Codable, Hashable, Sendable { case intake = 1, draft = 2 }

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

    public init(id: String, title: String, why: String, shapes: DocKind, round: QuestionRound = .intake, options: [Option], answer: Answer? = nil) {
        self.id = id
        self.title = title
        self.why = why
        self.shapes = shapes
        self.round = round
        self.options = options
        self.answer = answer
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

    public init(label: String, phase: DocKind = .product, state: CoverageState) {
        self.label = label
        self.phase = phase
        self.state = state
    }

    /// state.json from before phased Discovery has no `phase`; those topics load as `.product`.
    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        label = try c.decode(String.self, forKey: .label)
        phase = try c.decodeIfPresent(DocKind.self, forKey: .phase) ?? .product
        state = try c.decode(CoverageState.self, forKey: .state)
    }
}

public enum CoverageState: String, Codable, Hashable, Sendable { case covered, asking, notYet }

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
