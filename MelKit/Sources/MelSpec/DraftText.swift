import Foundation

/// Text edits Mel makes to the spec files while drafting and reviewing.
public enum DraftText {
    /// The file text for a drafting reply. REQUIREMENTS and TASKS start with a plan line
    /// (`5 stories`) that isn't part of the file; until that line is complete there is no file text.
    public static func file(fromReply reply: String, kind: DocKind) -> String {
        guard kind == .requirements || kind == .tasks, reply.first?.isNumber == true else { return reply }
        guard let newline = reply.firstIndex(where: \.isNewline) else { return "" }
        return String(reply[newline...].drop(while: \.isNewline))
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
