import Foundation

/// An `[!OPEN QUESTION]` callout in a file (B4 "Before you approve"). Answering it revises the file.
public struct OpenQuestion: Identifiable, Hashable, Sendable {
    public var kind: DocKind
    /// Position among the file's open-question callouts.
    public var index: Int
    public var text: String
    public var id: String { "\(kind.rawValue)-\(index)" }

    public init(kind: DocKind, index: Int, text: String) {
        self.kind = kind
        self.index = index
        self.text = text
    }

    public static func parse(_ text: String, kind: DocKind) -> [OpenQuestion] {
        MarkdownParser.blocks(text).compactMap { block in
            guard case .openQuestion(let index, let text) = block else { return nil }
            return OpenQuestion(kind: kind, index: index, text: text)
        }
    }
}

/// B6: the analyze run's JSON reply (V2.md §5 Analyze).
public struct AnalyzeResult: Codable, Hashable, Sendable {
    public var stats: [Stat]
    public var issues: [Issue]
    public var coverage: [CoverageRow]
    /// B6 "Analyzed …". Mel's clock, not the model's: a reply has none, so decoding one stamps now.
    public var analyzedAt: Date

    public init(stats: [Stat], issues: [Issue], coverage: [CoverageRow], analyzedAt: Date = .now) {
        self.stats = stats
        self.issues = issues
        self.coverage = coverage
        self.analyzedAt = analyzedAt
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        stats = try c.decode([Stat].self, forKey: .stats)
        issues = try c.decode([Issue].self, forKey: .issues)
        coverage = try c.decode([CoverageRow].self, forKey: .coverage)
        analyzedAt = try c.decodeIfPresent(Date.self, forKey: .analyzedAt) ?? .now
    }

    /// "14 of 15" · "requirements have a task".
    public struct Stat: Codable, Hashable, Sendable {
        public var value: String
        public var label: String

        public init(value: String, label: String) {
            self.value = value
            self.label = label
        }
    }

    public struct Issue: Codable, Identifiable, Hashable, Sendable {
        public var id: String
        public var kind: IssueKind
        /// "REQUIREMENTS 1.3 · EXPERIENCE › Confirm booking".
        public var location: String
        public var text: String
        /// Two actions, drawn left to right; the second is the primary one.
        public var actions: [Action]

        public init(id: String, kind: IssueKind, location: String, text: String, actions: [Action]) {
            self.id = id
            self.kind = kind
            self.location = location
            self.text = text
            self.actions = actions
        }
    }

    public enum IssueKind: String, Codable, Hashable, Sendable { case contradiction, noTask, qualityNotCovered, scopeCreep }

    /// "Add Task": `fix` is the instruction passed to the revise run of each file in `files`.
    public struct Action: Codable, Hashable, Sendable {
        public var label: String
        public var fix: String
        public var files: [DocKind]

        public init(label: String, fix: String, files: [DocKind]) {
            self.label = label
            self.fix = fix
            self.files = files
        }
    }

    /// One requirement (`1.3`, `Q1`) across the files after REQUIREMENTS. `screen` is nil without EXPERIENCE.md.
    public struct CoverageRow: Codable, Identifiable, Hashable, Sendable {
        public var id: String
        public var text: String
        public var screen: Mark?
        public var architecture: Mark
        public var task: Mark
        public var test: Mark

        public init(id: String, text: String, screen: Mark?, architecture: Mark, task: Mark, test: Mark) {
            self.id = id
            self.text = text
            self.screen = screen
            self.architecture = architecture
            self.task = task
            self.test = test
        }
    }

    public enum Mark: String, Codable, Hashable, Sendable { case covered, missing, conflict }

    /// Decodes the JSON object in `reply`; text around it is ignored.
    public static func decode(_ reply: String) throws -> AnalyzeResult {
        try JSONDecoder().decode(AnalyzeResult.self, from: jsonObject(in: reply))
    }
}

/// C1 "What this affects": one entry per stale file.
public struct ImpactResult: Codable, Hashable, Sendable {
    /// One line on what changed ("Late cancel window is 12 hours"); the saved decision's title. Empty if the reply has none.
    public var title: String
    public var items: [Item]

    public init(title: String = "", items: [Item]) {
        self.title = title
        self.items = items
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        title = try c.decodeIfPresent(String.self, forKey: .title) ?? ""
        items = try c.decode([Item].self, forKey: .items)
    }

    public struct Item: Codable, Hashable, Sendable {
        public var kind: DocKind
        /// "Copy on Confirm booking and Upcoming › Late cancel".
        public var what: String
        /// "2 places".
        public var count: String

        public init(kind: DocKind, what: String, count: String) {
            self.kind = kind
            self.what = what
            self.count = count
        }
    }

    public static func decode(_ reply: String) throws -> ImpactResult {
        try JSONDecoder().decode(ImpactResult.self, from: jsonObject(in: reply))
    }
}
