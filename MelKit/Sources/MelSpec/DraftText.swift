import Foundation

/// Text edits Mel makes to the spec files while drafting and reviewing.
public enum DraftText {
    /// The file text for a drafting reply: without step markers, the question trailer and a
    /// marker still being streamed. v1 replies to REQUIREMENTS and TASKS start with a plan line
    /// (`5 stories`), dropped too (the v1 e2e fixtures have one); every v2 file starts with `#`.
    public static func file(fromReply reply: String, kind: DocKind) -> String {
        let text = strippingMarkers(reply)
        guard kind == .requirements || kind == .tasks, text.first?.isNumber == true else { return text }
        guard let newline = text.firstIndex(where: \.isNewline) else { return "" }
        return String(text[newline...].drop(while: \.isNewline))
    }

    /// The last `<!-- mel:step N -->` the agent reached, or 0 before the first.
    public static func step(in reply: String) -> Int {
        var step = 0
        var rest = reply[...]
        while let marker = rest.range(of: "<!-- mel:step ") {
            let digits = rest[marker.upperBound...].prefix(while: \.isNumber)
            // Only a complete marker counts: "1" may still become "12".
            if let n = Int(digits), rest[digits.endIndex...].hasPrefix(" -->") { step = n }
            rest = rest[marker.upperBound...]
        }
        return step
    }

    /// `text` without step-marker lines, the `<!-- mel:questions … -->` trailer, and a
    /// comment still being streamed at the end.
    public static func strippingMarkers(_ text: String) -> String {
        var body = text[...]
        if let trailer = body.range(of: "<!-- mel:questions", options: .backwards) { body = body[..<trailer.lowerBound] }
        if let open = body.range(of: "<!--", options: .backwards), body[open.upperBound...].range(of: "-->") == nil {
            body = body[..<open.lowerBound]
        }
        let lines = body.split(omittingEmptySubsequences: false, whereSeparator: \.isNewline).filter { line in
            let t = line.trimming(while: \.isWhitespace)
            return !(t.hasPrefix("<!-- mel:step ") && t.hasSuffix("-->"))
        }
        var result = lines.joined(separator: "\n")
        if text.range(of: "<!-- mel:questions") != nil {
            while result.last?.isWhitespace == true { result.removeLast() }
            result += "\n"
        }
        return result
    }

    /// Up to 3 round-2 questions from the draft's trailer: `<!-- mel:questions [ … ] -->`.
    public static func questions(in reply: String, kind: DocKind) -> [Question] {
        guard let start = reply.range(of: "<!-- mel:questions", options: .backwards),
              let data = try? jsonObject(in: String(reply[start.upperBound...]), open: "[", close: "]"),
              let wire = try? JSONDecoder().decode([WireQuestion].self, from: data) else { return [] }
        return wire.prefix(3).map { $0.question(round: .draft, shapes: kind) }
    }

    /// Cuts `text` before its last `##` heading: that section may be incomplete. Ends with a
    /// blank line so appended text starts a new block. Text without a `##` heading is kept.
    public static func truncatedToLastCompleteSection(_ text: String) -> String {
        let lines = text.split(omittingEmptySubsequences: false, whereSeparator: \.isNewline)
        var inCode = false
        var last: Int?
        for (i, line) in lines.enumerated() {
            if line.hasPrefix("```") { inCode.toggle() }
            if !inCode, line.hasPrefix("## ") { last = i }
        }
        let kept = last.map { lines[..<$0] } ?? lines[...]
        let body = kept.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        return body.isEmpty ? "" : body + "\n\n"
    }

    /// Confirm: removes the callout wrapper and keeps its text. Nil when there is no such assumption.
    public static func confirmAssumption(_ index: Int, in text: String) -> String? {
        replaceAssumption(index, in: text) { $0 }
    }

    /// Change: replaces the callout with `newText`, without the wrapper.
    public static func changeAssumption(_ index: Int, to newText: String, in text: String) -> String? {
        replaceAssumption(index, in: text) { _ in
            newText.trimmingCharacters(in: .whitespacesAndNewlines).split(separator: "\n", omittingEmptySubsequences: false).map { $0[...] }
        }
    }

    /// Finds the `index`-th `> [!ASSUMPTION]` callout the way `MarkdownParser.blocks` counts them.
    private static func replaceAssumption(_ index: Int, in text: String, with replacement: ([Substring]) -> [Substring]) -> String? {
        var lines = text.split(omittingEmptySubsequences: false, whereSeparator: \.isNewline)
        var inCode = false
        var found = 0
        var i = 0
        while i < lines.count {
            let trimmed = lines[i].trimming(while: \.isWhitespace)
            if trimmed.hasPrefix("```") { inCode.toggle() }
            guard !inCode, trimmed.hasPrefix(">"), MarkdownParser.quoteContent(trimmed).uppercased() == "[!ASSUMPTION]" else {
                i += 1
                continue
            }
            var end = i + 1
            while end < lines.count, lines[end].trimming(while: \.isWhitespace).hasPrefix(">") { end += 1 }
            if found == index {
                let body = lines[(i + 1)..<end].map { MarkdownParser.quoteContent($0.trimming(while: \.isWhitespace)) }
                lines.replaceSubrange(i..<end, with: replacement(body))
                return lines.joined(separator: "\n")
            }
            found += 1
            i = end
        }
        return nil
    }
}
