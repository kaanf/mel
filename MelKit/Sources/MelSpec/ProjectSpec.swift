import Foundation

/// The project spec (`specs/current/`, OQ #45, V2-31, V2-34): how the app works today, one Markdown
/// file per area, every rule a `WHEN …, THEN …` line with an id that never changes (`B-2.1`: area 2,
/// rule 1). Specs describe changes against it; when one is built, Mel merges its deltas by id.
public struct ProjectSpec: Hashable, Sendable {
    public struct Rule: Hashable, Sendable {
        public var id: String
        public var text: String

        public init(id: String, text: String) { (self.id, self.text) = (id, text) }
    }

    public struct Area: Hashable, Sendable {
        /// `schedule.md`.
        public var file: String
        public var title: String
        /// The `2` in `B-2.1`.
        public var number: Int
        public var rules: [Rule]

        public init(file: String, title: String, number: Int, rules: [Rule]) {
            (self.file, self.title, self.number, self.rules) = (file, title, number, rules)
        }

        public var markdown: String {
            "# \(title)\n\nHow \(title.lowercased()) works today. Mel keeps this file up to date when a spec is built; the ids never change.\n\n"
                + rules.map { "- \($0.id) \($0.text)" }.joined(separator: "\n") + "\n"
        }
    }

    public var areas: [Area]

    public init(areas: [Area]) { self.areas = areas.sorted { $0.number < $1.number } }

    /// One area file: `# Title`, then `- B-2.1 WHEN …, THEN …` lines (wrapped lines joined). Nil without a title.
    public static func area(file: String, text: String) -> Area? {
        var title: String?
        var rules: [Rule] = []
        for line in text.split(separator: "\n", omittingEmptySubsequences: false) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if title == nil, trimmed.hasPrefix("# ") { title = String(trimmed.dropFirst(2)); continue }
            if trimmed.hasPrefix("- B-"), let space = trimmed.dropFirst(2).firstIndex(of: " ") {
                rules.append(Rule(id: String(trimmed[trimmed.index(trimmed.startIndex, offsetBy: 2)..<space]), text: String(trimmed[trimmed.index(after: space)...])))
            } else if !trimmed.isEmpty, line.first?.isWhitespace == true, !rules.isEmpty {
                rules[rules.count - 1].text += " " + trimmed
            }
        }
        guard let title else { return nil }
        let number = rules.first.flatMap { Int($0.id.dropFirst(2).prefix { $0.isNumber }) } ?? 0
        return Area(file: file, title: title, number: number, rules: rules)
    }

    /// The scan's areas (V2-0: written from the code, only behavior a user can see), numbered in order.
    public static func numbered(_ scanned: [(file: String, title: String, rules: [String])]) -> ProjectSpec {
        ProjectSpec(areas: scanned.enumerated().map { i, area in
            Area(file: area.file, title: area.title, number: i + 1, rules: area.rules.enumerated().map { Rule(id: "B-\(i + 1).\($0.offset + 1)", text: $0.element) })
        })
    }

    public func rule(_ id: String) -> (area: Area, rule: Rule)? {
        for area in areas { if let rule = area.rules.first(where: { $0.id == id }) { return (area, rule) } }
        return nil
    }

    /// For the prompts: every area with its rules; or, past `limit` characters, the areas whose title
    /// words appear in `about` (the idea and answers), so a big project spec doesn't ride along whole.
    public func promptText(about: String, limit: Int = 16_000) -> String {
        let all = areas.map { "### specs/current/\($0.file)\n\n" + $0.rules.map { "- \($0.id) \($0.text)" }.joined(separator: "\n") }
        if all.joined().count <= limit { return all.joined(separator: "\n\n") }
        let words = Set(about.lowercased().split { !$0.isLetter }.map(String.init))
        let picked = areas.indices.filter { i in areas[i].title.lowercased().split { !$0.isLetter }.contains { words.contains(String($0)) } }
        let others = areas.indices.filter { !picked.contains($0) }.map { "- \(areas[$0].file): \(areas[$0].title)" }
        return (picked.map { all[$0] } + (others.isEmpty ? [] : ["Other areas (rules not shown):\n" + others.joined(separator: "\n")])).joined(separator: "\n\n")
    }

    // MARK: Deltas (V2-31, V2-34)

    /// What a spec's criterion does to the project spec, from the tag at its end.
    public enum Delta: Hashable, Sendable {
        /// New behavior, in `file` (an area that may not exist yet).
        case adds(file: String, text: String)
        case changes(id: String, text: String)
        case removes(id: String)
        case keeps(id: String)
    }

    /// "WHEN …, THEN …. `Changes B-2.1`" → the text without the tag, and the tag.
    public static func tag(of criterion: String) -> (text: String, delta: String)? {
        guard criterion.hasSuffix("`"), let open = criterion.dropLast().lastIndex(of: "`") else { return nil }
        let tag = String(criterion[criterion.index(after: open)..<criterion.index(before: criterion.endIndex)])
        guard ["Adds", "Changes", "Removes", "Keeps"].contains(where: { tag.hasPrefix($0) }) else { return nil }
        return (criterion[..<open].trimmingCharacters(in: .whitespaces), tag)
    }

    /// The deltas of the criteria in a spec file (REQUIREMENTS.md or SPEC.md), in order.
    public static func deltas(in criteria: [(id: String, text: String)]) -> [Delta] {
        criteria.compactMap { criterion in
            guard let (text, tag) = tag(of: criterion.text) else { return nil }
            let parts = tag.split(separator: " ", maxSplits: 2).map(String.init)
            switch parts.first {
            case "Adds": return .adds(file: parts.count > 1 ? Self.fileName(parts[1...].joined(separator: " ")) : "general.md", text: text)
            case "Changes" where parts.count > 1: return .changes(id: parts[1], text: text)
            case "Removes" where parts.count > 1: return .removes(id: parts[1])
            case "Keeps" where parts.count > 1: return .keeps(id: parts[1])
            default: return nil
            }
        }
    }

    /// "to schedule.md", "Schedule" → "schedule.md".
    static func fileName(_ raw: String) -> String {
        var name = raw.lowercased().replacingOccurrences(of: "to ", with: "")
        if name.hasSuffix(".md") { name.removeLast(3) }
        let slug = name.split { !$0.isLetter && !$0.isNumber }.joined(separator: "-")
        return (slug.isEmpty ? "general" : slug) + ".md"
    }

    /// V2-34: one row per delta that changes a file: what it was and what it becomes.
    public struct Change: Hashable, Sendable {
        public enum Kind: Hashable, Sendable { case added, changed, removed }
        public var kind: Kind
        public var id: String
        public var file: String
        public var text: String
        public var before: String?
        public var newFile: Bool
    }

    /// The deltas merged by id: changed rules take the new text, removed ones go, added ones get the
    /// next id of their area (a new area the next number). No agent run (V2-34).
    public func merging(_ deltas: [Delta]) -> (spec: ProjectSpec, changes: [Change]) {
        var areas = self.areas
        var changes: [Change] = []
        for delta in deltas {
            switch delta {
            case .adds(let file, let text):
                let isNew = !areas.contains { $0.file == file }
                if isNew {
                    let title = file.dropLast(3).split(separator: "-").joined(separator: " ").capitalized
                    areas.append(Area(file: file, title: title, number: (areas.map(\.number).max() ?? 0) + 1, rules: []))
                }
                let i = areas.firstIndex { $0.file == file }!
                let next = (areas[i].rules.compactMap { Int($0.id.split(separator: ".").last ?? "") }.max() ?? 0) + 1
                let id = "B-\(areas[i].number).\(next)"
                areas[i].rules.append(Rule(id: id, text: text))
                changes.append(Change(kind: .added, id: id, file: file, text: text, before: nil, newFile: isNew))
            case .changes(let id, let text):
                guard let i = areas.firstIndex(where: { $0.rules.contains { $0.id == id } }), let j = areas[i].rules.firstIndex(where: { $0.id == id }) else { continue }
                changes.append(Change(kind: .changed, id: id, file: areas[i].file, text: text, before: areas[i].rules[j].text, newFile: false))
                areas[i].rules[j].text = text
            case .removes(let id):
                guard let i = areas.firstIndex(where: { $0.rules.contains { $0.id == id } }), let j = areas[i].rules.firstIndex(where: { $0.id == id }) else { continue }
                changes.append(Change(kind: .removed, id: id, file: areas[i].file, text: areas[i].rules[j].text, before: nil, newFile: false))
                areas[i].rules.remove(at: j)
            case .keeps:
                continue
            }
        }
        return (ProjectSpec(areas: areas), changes)
    }
}
