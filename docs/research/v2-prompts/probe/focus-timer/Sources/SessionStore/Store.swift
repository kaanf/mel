import Foundation
import TimerCore

public struct Session: Codable, Sendable { public var kind: Countdown.Kind; public var start: Date; public var end: Date }

/// Appends finished sessions to one JSON file per day. Writes are atomic.
public struct Store {
    public let folder: URL
    public init(folder: URL) { self.folder = folder }

    public func append(_ session: Session) throws {
        var all = try load(day: session.start)
        all.append(session)
        try JSONEncoder().encode(all).write(to: file(for: session.start), options: .atomic)
    }

    public func load(day: Date) throws -> [Session] {
        guard let data = try? Data(contentsOf: file(for: day)) else { return [] }
        return try JSONDecoder().decode([Session].self, from: data)
    }

    func file(for day: Date) -> URL {
        folder.appending(path: day.formatted(.iso8601.year().month().day()) + ".json")
    }
}
