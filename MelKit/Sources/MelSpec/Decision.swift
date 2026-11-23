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

    /// The next free id after `decisions` ("D-08").
    public static func nextID(after decisions: [Decision]) -> String { fatalError("stub") }

    /// DECISIONS.md, newest first. A replaced decision shows "Replaced by D-07".
    public static func markdown(_ decisions: [Decision]) -> String { fatalError("stub") }

    public static func parse(_ text: String) -> [Decision] { [] }
}
