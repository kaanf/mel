import Foundation

/// What Mel takes out of a drafting reply before it writes the file.
public enum DraftText {
    /// The file text for a drafting reply: without the question trailer and a comment still
    /// being streamed. `<!-- mel:step N -->` lines, which drafts wrote before 0.5 (and a session
    /// resumed from then still may), are dropped too. v1 replies to REQUIREMENTS and TASKS start with a plan line
    /// (`5 stories`), dropped too (the v1 e2e fixtures have one); every v2 file starts with `#`.
    public static func file(fromReply reply: String, kind: DocKind) -> String {
        let text = strippingMarkers(reply)
        guard kind == .requirements || kind == .tasks, text.first?.isNumber == true else { return text }
        guard let newline = text.firstIndex(where: \.isNewline) else { return "" }
        return String(text[newline...].drop(while: \.isNewline))
    }

    /// `text` without step-marker lines, the `<!-- mel:questions … -->` trailer, and a
    /// comment still being streamed at the end.
    public static func strippingMarkers(_ text: String) -> String {
        var body = text[...]
        if let trailer = body.range(of: "<!-- mel:questions", options: .backwards) { body = body[..<trailer.lowerBound] }
        if let open = body.range(of: "<!--", options: .backwards), body[open.upperBound...].range(of: "-->") == nil {
            body = body[..<open.lowerBound]
        }
        // Drop marker lines and the blank lines they leave: none at the start, never two in a row.
        var lines: [Substring] = []
        for line in body.split(omittingEmptySubsequences: false, whereSeparator: \.isNewline) {
            let t = line.trimming(while: \.isWhitespace)
            if t.hasPrefix("<!-- mel:step "), t.hasSuffix("-->") { continue }
            if t.isEmpty, lines.last?.trimming(while: \.isWhitespace).isEmpty ?? true { continue }
            lines.append(line)
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
}
