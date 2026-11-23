import Foundation

public enum Block: Hashable, Sendable {
    case heading(level: Int, text: String)
    case paragraph(String)
    case criterion(id: String, text: String)
    case task(id: String, text: String, done: Bool, covers: [String])
    case listItem(String)
    case assumption(index: Int, text: String)
    case code(String)
}

public struct DocSummary: Hashable, Sendable {
    public var stories: Int
    public var criteria: Int
    public var sections: Int
    public var tasks: Int
    public var assumptions: Int
    public var uncoveredCriteria: [String]

    public init(stories: Int = 0, criteria: Int = 0, sections: Int = 0, tasks: Int = 0, assumptions: Int = 0, uncoveredCriteria: [String] = []) {
        self.stories = stories
        self.criteria = criteria
        self.sections = sections
        self.tasks = tasks
        self.assumptions = assumptions
        self.uncoveredCriteria = uncoveredCriteria
    }
}

// Stub until 2.2: returns empty results so previews work.
public enum MarkdownParser {
    public static func blocks(_ text: String) -> [Block] { [] }

    public static func summary(_ text: String, kind: DocKind) -> DocSummary { DocSummary() }
}
