import Foundation

/// What removing a story takes with it (V2-8), found by ID without an agent run. Mel cuts the
/// story out of REQUIREMENTS.md itself; `instruction(for:)` is the patch run for each later file.
public struct StoryRemoval: Hashable, Sendable {
    /// The story's number, "2".
    public var story: String
    public var title: String
    public var criteria: [String]
    /// EXPERIENCE screens whose criteria are all this story's.
    public var screens: [String]
    /// Tasks that cover only this story's criteria.
    public var tasks: [Int]
    /// Tasks that cover other criteria too: they stay, without this story's IDs.
    public var sharedTasks: [Int]
    /// REQUIREMENTS.md without the story's section. An `<!-- MVP line -->` inside it is kept.
    public var requirements: String
    /// The section that was cut, for Restore.
    public var section: String

    /// Nil when REQUIREMENTS.md has no `## <story>. …` section. `experience` is nil for a size without EXPERIENCE.md.
    public init?(story: String, requirements: String, experience: String?, tasks: String) {
        var lines = requirements.split(omittingEmptySubsequences: false, whereSeparator: \.isNewline)
        guard let start = lines.firstIndex(where: { $0.hasPrefix("## \(story). ") }) else { return nil }
        let end = lines[(start + 1)...].firstIndex { $0.hasPrefix("## ") } ?? lines.endIndex
        let mvpLine = lines[start..<end].filter { $0.trimming(while: \.isWhitespace) == "<!-- MVP line -->" }
        self.story = story
        title = String(lines[start].dropFirst("## \(story). ".count))
        criteria = MarkdownParser.blocks(lines[start..<end].joined(separator: "\n")).compactMap { block in
            if case .criterion(let id, _) = block { id } else { nil }
        }
        section = lines[start..<end].filter { $0.trimming(while: \.isWhitespace) != "<!-- MVP line -->" }.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        lines.replaceSubrange(start..<end, with: mvpLine.isEmpty ? [] : mvpLine + [""])
        self.requirements = lines.joined(separator: "\n")

        let mine = Set(criteria)
        screens = MarkdownParser.screens(experience ?? "").filter { !$0.criteria.isEmpty && mine.isSuperset(of: $0.criteria) }.map(\.name)
        let touching = SpecTask.parse(tasks).filter { !mine.isDisjoint(with: $0.covers) }
        self.tasks = touching.filter { mine.isSuperset(of: $0.covers) }.map(\.number)
        sharedTasks = touching.filter { !mine.isSuperset(of: $0.covers) }.map(\.number)
    }

    /// The confirmation's line: "Also removes requirements 2.1 and 2.2, 2 screens in EXPERIENCE.md and task 3."
    public var summary: String {
        var parts: [String] = []
        if !criteria.isEmpty { parts.append("\(criteria.count == 1 ? "requirement" : "requirements") \(Self.list(criteria))") }
        if !screens.isEmpty { parts.append("\(screens.count) \(screens.count == 1 ? "screen" : "screens") in EXPERIENCE.md") }
        if !tasks.isEmpty { parts.append("\(tasks.count == 1 ? "task" : "tasks") \(Self.list(tasks.map(String.init)))") }
        return parts.isEmpty ? "" : "Also removes \(Self.list(parts))."
    }

    /// What the patch run of a later file is told; nil for a file the removal can't touch.
    public func instruction(for kind: DocKind) -> String? {
        let what = "Story \(story) “\(title)” was removed from REQUIREMENTS.md" + (criteria.isEmpty ? "." : ", with \(criteria.count == 1 ? "criterion" : "criteria") \(Self.list(criteria)).")
        switch kind {
        case .experience:
            let named = screens.isEmpty ? "" : " Remove \(screens.count == 1 ? "the screen" : "the screens") \(Self.list(screens))."
            return what + named + " Remove flows and steps that served only this story, and its IDs from every Covers line and Criteria cell."
        case .architecture:
            return what + " Remove whatever served only this story; keep everything other stories need."
        case .tasks:
            guard !tasks.isEmpty || !sharedTasks.isEmpty else { return nil }
            let removed = tasks.isEmpty ? "" : " Remove \(tasks.count == 1 ? "task" : "tasks") \(Self.list(tasks.map(String.init)))."
            let kept = sharedTasks.isEmpty ? "" : " In \(sharedTasks.count == 1 ? "task" : "tasks") \(Self.list(sharedTasks.map(String.init))), remove its IDs from Covers and the work that served only them."
            return what + removed + kept + " Renumber the tasks so there are no gaps, in `Parallel with` too."
        case .product:
            return what + " Remove the lines that described only this story."
        case .requirements, .spec:
            return nil
        }
    }

    /// "a", "a and b", "a, b and c".
    private static func list(_ items: [String]) -> String {
        items.count < 2 ? items.joined() : items.dropLast().joined(separator: ", ") + " and " + items[items.count - 1]
    }
}
