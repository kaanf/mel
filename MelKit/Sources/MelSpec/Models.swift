import Foundation

public struct Spec: Codable, Identifiable, Hashable, Sendable {
    public let id: UUID
    public var name: String
    public var idea: String
    public var folder: URL
    public var stage: Stage
    public var docs: [DocKind: DocStatus]
    public var questions: [Question]
    public var coverage: [CoverageItem]
    public var sessionID: String?

    /// A new spec starts in Discovery with every file locked.
    public init(id: UUID = UUID(), name: String, idea: String, folder: URL, stage: Stage = .discovery, docs: [DocKind: DocStatus] = DocKind.allLocked, questions: [Question] = [], coverage: [CoverageItem] = [], sessionID: String? = nil) {
        self.id = id
        self.name = name
        self.idea = idea
        self.folder = folder
        self.stage = stage
        self.docs = docs
        self.questions = questions
        self.coverage = coverage
        self.sessionID = sessionID
    }
}

public enum DocKind: String, Codable, CodingKeyRepresentable, CaseIterable, Hashable, Sendable {
    case product, requirements, design, tasks

    public var fileName: String { rawValue.uppercased() + ".md" }
    public var title: String { rawValue.capitalized }

    /// The file drafted after this one, or nil for TASKS.md.
    public var next: DocKind? {
        let all = Self.allCases
        let i = all.firstIndex(of: self)! + 1
        return i < all.count ? all[i] : nil
    }

    public static let allLocked = Dictionary(uniqueKeysWithValues: allCases.map { ($0, DocStatus.locked) })
}

public enum Stage: Codable, Hashable, Sendable {
    case discovery
    case drafting(DocKind)
    case review(DocKind)
    case stopped(DocKind, StopReason)
    case done
}

public enum DocStatus: String, Codable, Hashable, Sendable { case locked, writing, stopped, review, approved }

public struct Question: Codable, Identifiable, Hashable, Sendable {
    public let id: String
    public var title: String
    public var why: String
    public var shapes: DocKind
    public var options: [Option]
    public var answer: Answer?

    public init(id: String, title: String, why: String, shapes: DocKind, options: [Option], answer: Answer? = nil) {
        self.id = id
        self.title = title
        self.why = why
        self.shapes = shapes
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
}

public struct CoverageItem: Codable, Hashable, Sendable {
    public var label: String
    public var state: CoverageState

    public init(label: String, state: CoverageState) {
        self.label = label
        self.state = state
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
