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

/// B6: what Analyze found. Coverage, stats and the missing-task issues come from `coverage`, by
/// ID and without an agent run; the agent only adds contradictions (`add`).
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
        /// Board: the action the user picked, or what they typed instead.
        public var answer: Answer?
        /// Board: answered, and the next change run applies it.
        public var pending: Bool?

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

    /// One requirement (`1.3`, `Q1`) across the files after REQUIREMENTS. A nil mark is blank:
    /// `screen` without EXPERIENCE.md or for a quality requirement no screen names, `task` and
    /// `test` for a P2/P3 criterion without a task, `architecture` unless a contradiction is there
    /// (ARCHITECTURE.md carries no IDs to trace).
    public struct CoverageRow: Codable, Identifiable, Hashable, Sendable {
        public var id: String
        public var text: String
        public var screen: Mark?
        public var architecture: Mark?
        public var task: Mark?
        public var test: Mark?

        public init(id: String, text: String, screen: Mark?, architecture: Mark?, task: Mark?, test: Mark?) {
            self.id = id
            self.text = text
            self.screen = screen
            self.architecture = architecture
            self.task = task
            self.test = test
        }
    }

    public enum Mark: String, Codable, Hashable, Sendable { case covered, missing, conflict }

    /// A contradiction between files, from the analyze run's reply. `ids` are the requirements it is about.
    public struct Contradiction: Decodable, Hashable, Sendable {
        public var id: String
        public var location: String
        public var text: String
        public var ids: [String]?
        public var actions: [Action]
    }

    /// Decodes the reply's `{"issues": [...]}`; text around the object is ignored.
    public static func contradictions(in reply: String) throws -> [Contradiction] {
        struct Reply: Decodable { var issues: [Contradiction] }
        return try JSONDecoder().decode(Reply.self, from: jsonObject(in: reply)).issues
    }

    /// The checks Mel makes itself, by ID: every P1 criterion and every quality requirement has a
    /// task, a covering task has a Verify step, screens name a criterion. A story without a tag
    /// line counts as P1. `experience` is nil for a size without EXPERIENCE.md.
    public static func coverage(requirements: String, experience: String?, tasks: String) -> AnalyzeResult {
        var criteria: [(id: String, text: String, needsTask: Bool)] = []
        var isP1 = true
        for block in MarkdownParser.blocks(requirements) {
            switch block {
            case .heading(2, _): isP1 = true
            case .priority(let priority, _): isP1 = priority == "P1"
            case .criterion(let id, let text): criteria.append((id, text, isP1 || id.hasPrefix("Q")))
            default: break
            }
        }
        let known = Set(criteria.map(\.id))
        let specTasks = SpecTask.parse(tasks)
        let withTask = Set(specTasks.flatMap(\.covers))
        let withTest = Set(specTasks.filter { !$0.verify.isEmpty }.flatMap(\.covers))
        let screens = experience.map(MarkdownParser.screens) ?? []
        let onScreen = Set(screens.flatMap(\.criteria)).union(experience.map(MarkdownParser.flowCriteria) ?? [])

        var result = AnalyzeResult(stats: [], issues: [], coverage: [])
        for c in criteria {
            let isQuality = c.id.hasPrefix("Q")
            let task: Mark? = withTask.contains(c.id) ? .covered : c.needsTask ? .missing : nil
            let screen: Mark? = experience == nil ? nil : onScreen.contains(c.id) ? .covered : isQuality ? nil : .missing
            result.coverage.append(CoverageRow(id: c.id, text: c.text, screen: screen, architecture: nil, task: task,
                                               test: task == .covered ? (withTest.contains(c.id) ? .covered : .missing) : task))
            guard task == .missing else { continue }
            if isQuality {
                result.issues.append(Issue(id: "task-\(c.id)", kind: .qualityNotCovered, location: "REQUIREMENTS \(c.id)", text: "No task covers quality requirement \(c.id).", actions: [
                    Action(label: "Drop Requirement", fix: "Remove quality requirement \(c.id).", files: [.requirements]),
                    Action(label: "Add Task", fix: "Add \(c.id) to the Covers of the task that has to meet it, or add a task for it.", files: [.tasks]),
                ]))
            } else {
                result.issues.append(Issue(id: "task-\(c.id)", kind: .noTask, location: "REQUIREMENTS \(c.id)", text: "No task covers criterion \(c.id).", actions: [
                    Action(label: "Move to Later", fix: "Criterion \(c.id) has no task. Tag its story P2 and move the story below the MVP line.", files: [.requirements]),
                    Action(label: "Add Task", fix: "Add a task that covers criterion \(c.id).", files: [.tasks]),
                ]))
            }
        }

        func stat(_ rows: [CoverageRow], _ label: String) {
            guard !rows.isEmpty else { return }
            result.stats.append(Stat(value: "\(rows.count { $0.task == .covered }) of \(rows.count)", label: label))
        }
        let needed = Set(criteria.filter(\.needsTask).map(\.id))
        stat(result.coverage.filter { !$0.id.hasPrefix("Q") && needed.contains($0.id) }, "P1 criteria have a task")
        stat(result.coverage.filter { $0.id.hasPrefix("Q") }, "quality requirements have a task")
        if !screens.isEmpty {
            let traced = screens.count { !known.isDisjoint(with: $0.criteria) }
            result.stats.append(Stat(value: "\(traced) of \(screens.count)", label: "screens trace to a criterion"))
        }
        return result
    }

    /// After the files changed: Mel's own checks again, free. Contradictions stay as they are,
    /// answered or not; only a new check run looks for them again.
    public mutating func refresh(requirements: String, experience: String?, tasks: String) {
        let kept = issues.filter { $0.kind == .contradiction }
        var fresh = Self.coverage(requirements: requirements, experience: experience, tasks: tasks)
        fresh.stats.append(Stat(value: "\(kept.count)", label: kept.count == 1 ? "contradiction between files" : "contradictions between files"))
        fresh.issues.insert(contentsOf: kept, at: 0)
        fresh.analyzedAt = analyzedAt
        self = fresh
    }

    /// Adds the agent's contradictions: listed first, counted in the stats, and marked `conflict`
    /// on their rows in the columns of the files their actions change.
    public mutating func add(_ found: [Contradiction]) {
        issues.insert(contentsOf: found.map { Issue(id: $0.id, kind: .contradiction, location: $0.location, text: $0.text, actions: $0.actions) }, at: 0)
        stats.append(Stat(value: "\(found.count)", label: found.count == 1 ? "contradiction between files" : "contradictions between files"))
        for contradiction in found {
            let files = Set(contradiction.actions.flatMap(\.files))
            for i in coverage.indices where contradiction.ids?.contains(coverage[i].id) == true {
                if files.contains(.experience), coverage[i].screen != nil { coverage[i].screen = .conflict }
                if files.contains(.architecture) { coverage[i].architecture = .conflict }
                if files.contains(.tasks) { coverage[i].task = .conflict }
            }
        }
    }
}
