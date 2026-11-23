import Foundation

public enum Block: Hashable, Sendable {
    case heading(level: Int, text: String)
    case paragraph(String)
    case criterion(id: String, text: String)        // "1.1" or "Q1", EARS text
    case task(id: String, text: String, done: Bool, covers: [String])
    case listItem(String)
    case orderedItem(number: Int, text: String)      // EXPERIENCE flow steps
    case assumption(index: Int, text: String)        // index = order in file, used by confirm/change
    case openQuestion(index: Int, text: String)      // `[!OPEN QUESTION]`, counted separately
    case priority(String, mvp: Bool)                 // story tag line `P1 · MVP`
    case source(String)                              // `Source: …`
    case covers([String])                            // flow `Covers: 1.1, 1.2`
    case mvpLine                                     // `<!-- MVP line -->` in REQUIREMENTS
    case table(header: [String], rows: [[String]])
    case code(String)
}

public struct DocSummary: Hashable, Sendable {
    public var stories: Int
    public var mvpStories: Int
    public var criteria: Int
    public var quality: Int
    public var sections: Int
    public var tasks: Int
    public var assumptions: Int
    public var openQuestions: Int
    public var flows: Int
    public var screens: Int
    /// Screen states prefixed `!` in EXPERIENCE's table.
    public var missingStates: Int
    public var uncoveredCriteria: [String]

    public init(stories: Int = 0, mvpStories: Int = 0, criteria: Int = 0, quality: Int = 0, sections: Int = 0, tasks: Int = 0, assumptions: Int = 0, openQuestions: Int = 0, flows: Int = 0, screens: Int = 0, missingStates: Int = 0, uncoveredCriteria: [String] = []) {
        self.stories = stories
        self.mvpStories = mvpStories
        self.criteria = criteria
        self.quality = quality
        self.sections = sections
        self.tasks = tasks
        self.assumptions = assumptions
        self.openQuestions = openQuestions
        self.flows = flows
        self.screens = screens
        self.missingStates = missingStates
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
        var table: [[String]]?
        var callout: (open: Bool, lines: [Substring])?
        var assumptionIndex = 0
        var openIndex = 0
        // The list item the next indented line continues, and its text so far.
        var item: String?
        // The task whose indented sub-items follow.
        var currentTask: Int?

        func flushParagraph() {
            guard !paragraph.isEmpty else { return }
            blocks.append(.paragraph(paragraph.joined(separator: " ")))
            paragraph = []
        }
        func flushCallout() {
            guard let (open, lines) = callout else { return }
            let text = lines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
            if open {
                blocks.append(.openQuestion(index: openIndex, text: text))
                openIndex += 1
            } else {
                blocks.append(.assumption(index: assumptionIndex, text: text))
                assumptionIndex += 1
            }
            callout = nil
        }
        func flushTable() {
            guard let rows = table else { return }
            // Row 2 is the `|---|` separator.
            let body = rows.dropFirst().filter { !$0.allSatisfy { $0.allSatisfy { "-: ".contains($0) } } }
            blocks.append(.table(header: rows.first ?? [], rows: Array(body)))
            table = nil
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
            if callout != nil {
                if trimmed.hasPrefix(">") {
                    callout!.lines.append(quoteContent(trimmed))
                    continue
                }
                flushCallout()
            }
            if table != nil {
                if trimmed.hasPrefix("|") {
                    table!.append(cells(trimmed))
                    continue
                }
                flushTable()
            }
            let indented = line.first?.isWhitespace == true
            if let text = item, indented, !trimmed.isEmpty, listItemText(trimmed) == nil, !trimmed.hasPrefix(">") {
                // A wrapped list item: join and classify again (a criterion's SHALL may be on line 2).
                let joined = text + " " + trimmed
                item = joined
                var rebuilt = listBlock(joined[...])
                if case .task(let id, let t, let done, _) = rebuilt, case .task(_, _, _, let covers) = blocks.last {
                    rebuilt = .task(id: id, text: t, done: done, covers: covers)
                }
                blocks[blocks.count - 1] = rebuilt
                continue
            }
            item = nil
            if !indented, !trimmed.isEmpty { currentTask = nil }

            if trimmed.isEmpty {
                flushParagraph()
            } else if trimmed.hasPrefix("<!--"), trimmed.hasSuffix("-->") {
                // The MVP line is a comment so it stays invisible elsewhere; other comments are skipped.
                if trimmed.dropFirst(4).dropLast(3).trimming(while: \.isWhitespace).lowercased() == "mvp line" {
                    flushParagraph()
                    blocks.append(.mvpLine)
                }
            } else if trimmed.hasPrefix("```") {
                flushParagraph()
                code = []
            } else if trimmed.hasPrefix(">"), let open = calloutKind(quoteContent(trimmed)) {
                flushParagraph()
                callout = (open, [])
            } else if trimmed.hasPrefix("|") {
                flushParagraph()
                table = [cells(trimmed)]
            } else if let heading = heading(trimmed) {
                flushParagraph()
                blocks.append(heading)
            } else if let special = lineBlock(trimmed) {
                flushParagraph()
                blocks.append(special)
            } else if let listItem = listItemText(trimmed) {
                flushParagraph()
                // `Covers:` may follow other sub-items (`Priority:`) of the same task.
                if indented, let covers = coversList(listItem), let i = currentTask, case .task(let id, let text, let done, _) = blocks[i] {
                    blocks[i] = .task(id: id, text: text, done: done, covers: covers)
                } else if !indented, let number = orderedNumber(trimmed) {
                    blocks.append(.orderedItem(number: number, text: String(listItem)))
                } else {
                    blocks.append(listBlock(listItem))
                    if !indented {
                        item = String(listItem)
                        if case .task = blocks.last { currentTask = blocks.count - 1 }
                    }
                }
            } else if trimmed.hasPrefix(">") {
                paragraph.append(quoteContent(trimmed))
            } else {
                paragraph.append(trimmed)
            }
        }
        if let lines = code { blocks.append(.code(lines.joined(separator: "\n"))) }
        flushCallout()
        flushTable()
        flushParagraph()
        return blocks
    }

    /// Counts for the review summary. `uncoveredCriteria` stays empty here: it needs both
    /// REQUIREMENTS.md and TASKS.md, see `uncoveredCriteria(requirements:tasks:)`.
    public static func summary(_ text: String, kind: DocKind) -> DocSummary {
        var summary = DocSummary()
        var inStory = false
        for block in blocks(text) {
            switch block {
            case .heading(2, let title):
                summary.sections += 1
                inStory = kind == .requirements && leadingID(title) != nil
                if inStory { summary.stories += 1 }
                if kind == .experience, title.hasPrefix("Flow ") { summary.flows += 1 }
            case .priority(_, let mvp): if inStory, mvp { summary.mvpStories += 1 }
            case .criterion(let id, _): if id.hasPrefix("Q") { summary.quality += 1 } else { summary.criteria += 1 }
            case .task: summary.tasks += 1
            case .assumption: summary.assumptions += 1
            case .openQuestion: summary.openQuestions += 1
            case .table(let header, let rows) where kind == .experience && header.first == "Screen":
                summary.screens += rows.count
                for row in rows where row.count > 1 {
                    summary.missingStates += row[1].split(separator: ",").filter { $0.trimming(while: \.isWhitespace).hasPrefix("!") }.count
                }
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

    /// `[!ASSUMPTION]` → false, `[!OPEN QUESTION]` → true, else nil.
    private static func calloutKind(_ content: Substring) -> Bool? {
        switch content.uppercased() {
        case "[!ASSUMPTION]": false
        case "[!OPEN QUESTION]": true
        default: nil
        }
    }

    /// One-line REQUIREMENTS and EXPERIENCE markers.
    private static func lineBlock(_ line: Substring) -> Block? {
        if line.hasPrefix("Source:") { return .source(String(line.dropFirst("Source:".count).trimming(while: \.isWhitespace))) }
        if line.hasPrefix("Covers:"), let ids = coversList(line) { return .covers(ids) }
        // `P1` or `P1 · MVP`.
        let parts = line.split(separator: "·").map { $0.trimming(while: \.isWhitespace) }
        guard let p = parts.first, p.count == 2, p.first == "P", p.last?.isNumber == true,
              parts.count == 1 || (parts.count == 2 && parts[1] == "MVP") else { return nil }
        return .priority(String(p), mvp: parts.count == 2)
    }

    /// `| a | b |` → ["a", "b"].
    private static func cells(_ line: Substring) -> [String] {
        var inner = line.dropFirst()
        if inner.hasSuffix("|") { inner = inner.dropLast() }
        return inner.split(separator: "|", omittingEmptySubsequences: false).map { String($0.trimming(while: \.isWhitespace)) }
    }

    private static func orderedNumber(_ line: Substring) -> Int? {
        let digits = line.prefix(while: \.isNumber)
        return digits.isEmpty || !line.dropFirst(digits.count).hasPrefix(". ") ? nil : Int(digits)
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
        // Quality requirement: `Q<n> …`.
        let q = item.dropFirst().prefix(while: \.isNumber)
        if item.first == "Q", !q.isEmpty, item.dropFirst(q.count + 1).first == " " {
            return .criterion(id: "Q" + q, text: String(item.dropFirst(q.count + 2)))
        }
        return .listItem(String(item))
    }

    /// `Covers: 1.1, Q1` → ["1.1", "Q1"]; `Covers: —` → [].
    private static func coversList(_ item: Substring) -> [String]? {
        guard item.hasPrefix("Covers:") else { return nil }
        return item.dropFirst("Covers:".count).split(separator: ",").compactMap { part in
            let id = part.trimming(while: \.isWhitespace)
            if id.first == "Q" { return leadingID(id.dropFirst()).map { "Q" + $0 } }
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
    static func quoteContent(_ line: Substring) -> Substring {
        let rest = line.dropFirst()
        return rest.first == " " ? rest.dropFirst() : rest
    }
}

extension Substring {
    func trimming(while predicate: (Character) -> Bool) -> Substring {
        guard let start = firstIndex(where: { !predicate($0) }), let end = lastIndex(where: { !predicate($0) }) else {
            return self[endIndex...]
        }
        return self[start...end]
    }
}
