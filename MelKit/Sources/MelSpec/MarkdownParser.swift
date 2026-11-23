import Foundation

public enum Block: Hashable, Sendable {
    case heading(level: Int, text: String)
    case paragraph(String)
    case criterion(id: String, text: String)        // "1.1", EARS text
    case task(id: String, text: String, done: Bool, covers: [String])
    case listItem(String)
    case assumption(index: Int, text: String)        // index = order in file, used by confirm/change
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

/// Line-based parser for the format in SPEC-FORMAT.md. Not a general Markdown parser:
/// anything it doesn't recognize becomes a paragraph.
public enum MarkdownParser {
    public static func blocks(_ text: String) -> [Block] {
        var blocks: [Block] = []
        var paragraph: [Substring] = []
        var code: [Substring]?
        var assumption: [Substring]?
        var assumptionIndex = 0

        func flushParagraph() {
            guard !paragraph.isEmpty else { return }
            blocks.append(.paragraph(paragraph.joined(separator: " ")))
            paragraph = []
        }
        func flushAssumption() {
            guard let lines = assumption else { return }
            let text = lines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
            blocks.append(.assumption(index: assumptionIndex, text: text))
            assumptionIndex += 1
            assumption = nil
        }

        // `isNewline` also matches "\r\n", which Swift treats as one Character.
        for line in text.split(omittingEmptySubsequences: false, whereSeparator: \.isNewline) {
            let trimmed = line.trimming(while: \.isWhitespace)

            if code != nil {
                if trimmed.hasPrefix("```") {
                    blocks.append(.code(code!.joined(separator: "\n")))
                    code = nil
                } else {
                    code!.append(line)
                }
                continue
            }
            if assumption != nil {
                if trimmed.hasPrefix(">") {
                    assumption!.append(quoteContent(trimmed))
                    continue
                }
                flushAssumption()
            }
            if trimmed.isEmpty {
                flushParagraph()
            } else if trimmed.hasPrefix("```") {
                flushParagraph()
                code = []
            } else if trimmed.hasPrefix(">"), quoteContent(trimmed).uppercased() == "[!ASSUMPTION]" {
                flushParagraph()
                assumption = []
            } else if let heading = heading(trimmed) {
                flushParagraph()
                blocks.append(heading)
            } else if let item = listItemText(trimmed) {
                flushParagraph()
                let indented = line.first?.isWhitespace == true
                if indented, let covers = coversList(item), case .task(let id, let text, let done, _) = blocks.last {
                    blocks[blocks.count - 1] = .task(id: id, text: text, done: done, covers: covers)
                } else {
                    blocks.append(listBlock(item))
                }
            } else if trimmed.hasPrefix(">") {
                paragraph.append(quoteContent(trimmed))
            } else {
                paragraph.append(trimmed)
            }
        }
        if let lines = code { blocks.append(.code(lines.joined(separator: "\n"))) }
        flushAssumption()
        flushParagraph()
        return blocks
    }

    /// Counts for the review summary. `uncoveredCriteria` stays empty here: it needs both
    /// REQUIREMENTS.md and TASKS.md, see `uncoveredCriteria(requirements:tasks:)`.
    public static func summary(_ text: String, kind: DocKind) -> DocSummary {
        let blocks = blocks(text)
        var summary = DocSummary()
        for (i, block) in blocks.enumerated() {
            switch block {
            case .heading(2, let title):
                summary.sections += 1
                // Story: `## <n>. <title>` followed by a paragraph starting "As a".
                if kind == .requirements, leadingID(title) != nil, i + 1 < blocks.count,
                   case .paragraph(let next) = blocks[i + 1], next.hasPrefix("As a") {
                    summary.stories += 1
                }
            case .criterion: summary.criteria += 1
            case .task: summary.tasks += 1
            case .assumption: summary.assumptions += 1
            default: break
            }
        }
        return summary
    }

    /// Criterion IDs from REQUIREMENTS.md that no task in TASKS.md lists under `Covers:`, in file order.
    public static func uncoveredCriteria(requirements: String, tasks: String) -> [String] {
        var covered = Set<String>()
        for case .task(_, _, _, let covers) in blocks(tasks) { covered.formUnion(covers) }
        return blocks(requirements).compactMap { block in
            guard case .criterion(let id, _) = block, !covered.contains(id) else { return nil }
            return id
        }
    }

    // MARK: - Line helpers

    private static func heading(_ line: Substring) -> Block? {
        let level = line.prefix(while: { $0 == "#" }).count
        guard (1...6).contains(level), line.dropFirst(level).first == " " else { return nil }
        return .heading(level: level, text: String(line.dropFirst(level + 1).trimming(while: \.isWhitespace)))
    }

    /// Text after `- `, `* `, `+ ` or `1. `, or nil when the line isn't a list item.
    private static func listItemText(_ line: Substring) -> Substring? {
        if let first = line.first, "-*+".contains(first), line.dropFirst().first == " " {
            return line.dropFirst(2)
        }
        let digits = line.prefix(while: \.isNumber)
        if !digits.isEmpty, line.dropFirst(digits.count).hasPrefix(". ") {
            return line.dropFirst(digits.count + 2)
        }
        return nil
    }

    private static func listBlock(_ item: Substring) -> Block {
        for (marker, done) in [("[ ] ", false), ("[x] ", true), ("[X] ", true)] where item.hasPrefix(marker) {
            let rest = item.dropFirst(marker.count)
            let id = leadingID(rest)
            let text = id.map { rest.dropFirst($0.count).trimming(while: { $0 == "." || $0 == " " }) } ?? rest
            return .task(id: id.map(String.init) ?? "", text: String(text), done: done, covers: [])
        }
        // Criterion: `<n>.<m> ` containing SHALL.
        if let id = leadingID(item), id.contains("."), item.dropFirst(id.count).first == " ", item.contains("SHALL") {
            return .criterion(id: String(id), text: String(item.dropFirst(id.count + 1)))
        }
        return .listItem(String(item))
    }

    /// `Covers: 1.1, 1.2` → ["1.1", "1.2"]; `Covers: —` → [].
    private static func coversList(_ item: Substring) -> [String]? {
        guard item.hasPrefix("Covers:") else { return nil }
        return item.dropFirst("Covers:".count).split(separator: ",").compactMap { part in
            let id = part.trimming(while: \.isWhitespace)
            return leadingID(id).map(String.init)
        }
    }

    /// Leading "12" or "1.2" (no trailing dot), or nil.
    private static func leadingID(_ s: Substring) -> Substring? {
        let token = s.prefix(while: { $0.isNumber || $0 == "." })
        let id = token.hasSuffix(".") ? token.dropLast() : token
        return id.first?.isNumber == true && id.last?.isNumber == true ? id : nil
    }

    private static func leadingID(_ s: String) -> Substring? { leadingID(s[...]) }

    /// `> text` → `text`.
    private static func quoteContent(_ line: Substring) -> Substring {
        let rest = line.dropFirst()
        return rest.first == " " ? rest.dropFirst() : rest
    }
}

private extension Substring {
    func trimming(while predicate: (Character) -> Bool) -> Substring {
        guard let start = firstIndex(where: { !predicate($0) }), let end = lastIndex(where: { !predicate($0) }) else {
            return self[endIndex...]
        }
        return self[start...end]
    }
}
