import Foundation

nonisolated enum Block: Hashable, Sendable {
    case heading(level: Int, text: String)
    case paragraph(String)
    case criterion(id: String, text: String)
    case task(id: String, text: String, done: Bool, covers: [String])
    case listItem(String)
    case assumption(index: Int, text: String)
    case code(String)
}

nonisolated struct DocSummary: Hashable, Sendable {
    var stories: Int
    var criteria: Int
    var sections: Int
    var tasks: Int
    var assumptions: Int
    var uncoveredCriteria: [String]
}

// Stub until 2.2: returns empty results so previews work.
nonisolated enum MarkdownParser {
    static func blocks(_ text: String) -> [Block] { [] }

    static func summary(_ text: String, kind: DocKind) -> DocSummary {
        DocSummary(stories: 0, criteria: 0, sections: 0, tasks: 0, assumptions: 0, uncoveredCriteria: [])
    }
}
