import Foundation

/// A story in REQUIREMENTS.md, as the board's Plan shows it.
public struct Story: Identifiable, Hashable, Sendable {
    /// The story's number, "2".
    public var id: String
    public var title: String
    /// Its "As a …, I want …" sentence.
    public var line: String
    /// "P1", or "" for a story without a tag line.
    public var priority: String
    /// In the first version: tagged MVP, or not tagged at all. Otherwise Later.
    public var isFirst: Bool
    public var criteria: [String]

    public static func parse(_ requirements: String) -> [Story] {
        var stories: [Story] = []
        var inStory = false
        for block in MarkdownParser.blocks(requirements) {
            switch block {
            case .heading(2, let text):
                let number = text.prefix(while: \.isNumber)
                inStory = !number.isEmpty && text.dropFirst(number.count).hasPrefix(". ")
                if inStory { stories.append(Story(id: String(number), title: String(text.dropFirst(number.count + 2)), line: "", priority: "", isFirst: true, criteria: [])) }
            case .priority(let priority, let mvp) where inStory:
                stories[stories.count - 1].priority = priority
                stories[stories.count - 1].isFirst = mvp
            case .paragraph(let text) where inStory && stories[stories.count - 1].line.isEmpty:
                stories[stories.count - 1].line = text
            case .criterion(let id, _) where inStory:
                stories[stories.count - 1].criteria.append(id)
            default:
                break
            }
        }
        return stories
    }

    /// REQUIREMENTS.md with story `id` moved between First version and Later, with no agent run:
    /// its tag line becomes `P2` or `P1 · MVP`, and its section moves to the other side of the
    /// `<!-- MVP line -->` so the line stays true. Nil when there is no such story.
    public static func move(_ id: String, toLater: Bool, in requirements: String) -> String? {
        var lines = requirements.split(omittingEmptySubsequences: false, whereSeparator: \.isNewline).map(String.init)
        func isBlank(_ line: String) -> Bool { line.allSatisfy(\.isWhitespace) }
        func isMVPLine(_ line: String) -> Bool { line.trimmingCharacters(in: .whitespaces) == "<!-- MVP line -->" }
        guard let start = lines.firstIndex(where: { $0.hasPrefix("## \(id). ") }) else { return nil }
        let end = lines[(start + 1)...].firstIndex { $0.hasPrefix("## ") || isMVPLine($0) } ?? lines.endIndex
        var section = Array(lines[start..<end])
        while let last = section.last, isBlank(last) { section.removeLast() }
        let tag = toLater ? "P2" : "P1 · MVP"
        if let i = section.firstIndex(where: { $0.wholeMatch(of: /P\d(\s*·\s*MVP)?\s*/) != nil }) {
            section[i] = tag
        } else {
            section.insert(contentsOf: ["", tag], at: 1)
        }
        lines.removeSubrange(start..<end)
        if let line = lines.firstIndex(where: isMVPLine) {
            lines.insert(contentsOf: [""] + section + [""], at: toLater ? line + 1 : line)
        } else {
            lines.insert(contentsOf: section + [""], at: start)
        }
        // The move leaves doubled blank lines behind.
        var result: [String] = []
        for line in lines where !(isBlank(line) && result.last.map(isBlank) == true) { result.append(line) }
        return result.joined(separator: "\n")
    }
}
