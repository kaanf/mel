import Foundation

/// One `## D-07 · Title` entry in DECISIONS.md (V2.md §6). Mel writes the file from these.
public struct Decision: Codable, Identifiable, Hashable, Sendable {
    /// "D-07".
    public var id: String
    public var title: String
    public var reason: String
    /// "You", "Confirmed in review", "Discovery Q2".
    public var source: String
    public var date: Date
    /// The decision this one replaces ("D-03").
    public var replaces: String?
    /// Criteria it affects ("1.3").
    public var affects: [String]

    public init(id: String, title: String, reason: String, source: String, date: Date, replaces: String? = nil, affects: [String] = []) {
        self.id = id
        self.title = title
        self.reason = reason
        self.source = source
        self.date = date
        self.replaces = replaces
        self.affects = affects
    }

    /// The decision that replaced this one, if any ("Replaced by D-07").
    public func replacedBy(in decisions: [Decision]) -> String? {
        decisions.first { $0.replaces == id }?.id
    }

    /// The next free id after `decisions` ("D-08").
    public static func nextID(after decisions: [Decision]) -> String {
        let last = decisions.compactMap { Int($0.id.dropFirst(2)) }.max() ?? 0
        return String(format: "D-%02d", last + 1)
    }

    /// DECISIONS.md, newest first.
    public static func markdown(_ decisions: [Decision]) -> String {
        let entries = decisions.sorted { (Int($0.id.dropFirst(2)) ?? 0) > (Int($1.id.dropFirst(2)) ?? 0) }.map { d in
            var lines = ["## \(d.id) · \(d.title)", "", d.reason.trimmingCharacters(in: .whitespacesAndNewlines), "", "- Source: \(d.source) · \(d.date.formatted(dateStyle))"]
            if let replaces = d.replaces { lines.append("- Replaces: \(replaces)") }
            if !d.affects.isEmpty { lines.append("- Affects: \(d.affects.joined(separator: ", "))") }
            return lines.joined(separator: "\n")
        }
        return (["# Decisions"] + entries).joined(separator: "\n\n") + "\n"
    }

    public static func parse(_ text: String) -> [Decision] {
        var decisions: [Decision] = []
        var current: Decision?
        var reason: [Substring] = []

        func flush() {
            guard var d = current else { return }
            d.reason = reason.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
            decisions.append(d)
            current = nil
            reason = []
        }

        for line in text.split(omittingEmptySubsequences: false, whereSeparator: \.isNewline) {
            if line.hasPrefix("## D-") {
                flush()
                let heading = line.dropFirst(3)
                let parts = heading.split(separator: "·", maxSplits: 1).map { String($0.trimming(while: \.isWhitespace)) }
                current = Decision(id: parts[0], title: parts.count > 1 ? parts[1] : "", reason: "", source: "", date: .distantPast)
            } else if current != nil, line.hasPrefix("- Source:") {
                let value = line.dropFirst("- Source:".count)
                let parts = value.split(separator: "·").map { String($0.trimming(while: \.isWhitespace)) }
                current!.source = parts.dropLast(parts.count > 1 ? 1 : 0).joined(separator: " · ")
                if parts.count > 1, let date = try? Date(parts.last!, strategy: dateStyle) { current!.date = date }
            } else if current != nil, line.hasPrefix("- Replaces:") {
                current!.replaces = String(line.dropFirst("- Replaces:".count).trimming(while: \.isWhitespace))
            } else if current != nil, line.hasPrefix("- Affects:") {
                current!.affects = line.dropFirst("- Affects:".count).split(separator: ",").map { String($0.trimming(while: \.isWhitespace)) }
            } else if current != nil {
                reason.append(line)
            }
        }
        flush()
        return decisions
    }

    /// `2026-11-23`, in the user's time zone.
    private static var dateStyle: Date.ISO8601FormatStyle { Date.ISO8601FormatStyle(timeZone: .current).year().month().day() }
}
