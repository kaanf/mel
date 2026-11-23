import Foundation

nonisolated struct Spec: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    var name: String
    var idea: String
    var folder: URL
    var stage: Stage
    var docs: [DocKind: DocStatus]
    var questions: [Question]
    var coverage: [CoverageItem]
    var sessionID: String?
}

nonisolated enum DocKind: String, Codable, CaseIterable, Hashable, Sendable {
    case product, requirements, design, tasks

    var fileName: String { rawValue.uppercased() + ".md" }
    var title: String { rawValue.capitalized }
}

nonisolated enum Stage: Codable, Hashable, Sendable {
    case discovery
    case drafting(DocKind)
    case review(DocKind)
    case stopped(DocKind, StopReason)
    case done
}

nonisolated enum DocStatus: String, Codable, Hashable, Sendable { case locked, writing, stopped, review, approved }

nonisolated struct Question: Codable, Identifiable, Hashable, Sendable {
    let id: String
    var title: String
    var why: String
    var shapes: DocKind
    var options: [Option]
    var answer: Answer?
}

nonisolated struct Option: Codable, Hashable, Sendable {
    var label: String
    var note: String
    var suggested: Bool
}

nonisolated enum Answer: Codable, Hashable, Sendable {
    case option(Int, note: String?)
    case agentDecides
}

nonisolated struct CoverageItem: Codable, Hashable, Sendable {
    var label: String
    var state: CoverageState
}

nonisolated enum CoverageState: String, Codable, Hashable, Sendable { case covered, asking, notYet }

nonisolated enum StopReason: Codable, Hashable, Sendable {
    case user
    case usageLimit(resetsAt: Date?)
    case signedOut
    case crashed(String)
    case timeout
}

nonisolated struct ActivityLine: Hashable, Identifiable, Sendable {
    let id = UUID()
    var at: Date
    var text: String
}
