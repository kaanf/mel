import Foundation

/// B1 Quick fix fields: Happens now / Should happen / Where.
public struct BugReport: Codable, Hashable, Sendable {
    public var now: String
    public var should: String
    public var `where`: String

    public init(now: String = "", should: String = "", where: String = "") {
        self.now = now
        self.should = should
        self.where = `where`
    }

    /// What goes into `Spec.idea`, after the "What's wrong?" text.
    public var ideaText: String {
        [("Happens now", now), ("Should happen", should), ("Where", `where`)]
            .filter { !$0.1.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .map { "\($0.0): \($0.1.trimmingCharacters(in: .whitespacesAndNewlines))" }
            .joined(separator: "\n")
    }
}

/// AGENTS.md: Mel owns only the block between its markers (V2.md §5 Handoff).
public enum AgentsFile {
    public static let begin = "<!-- mel:begin -->"
    public static let end = "<!-- mel:end -->"

    /// `existing` with Mel's block replaced by `block`, or with the block appended when there is none.
    public static func merge(existing: String?, block: String) -> String {
        let marked = "\(begin)\n\(block.trimmingCharacters(in: .whitespacesAndNewlines))\n\(end)"
        guard let existing, !existing.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return marked + "\n" }
        if let start = existing.range(of: begin), let stop = existing.range(of: end, range: start.upperBound..<existing.endIndex) {
            return existing.replacingCharacters(in: start.lowerBound..<stop.upperBound, with: marked)
        }
        var text = existing
        while text.last?.isNewline == true { text.removeLast() }
        return text + "\n\n" + marked + "\n"
    }
}
