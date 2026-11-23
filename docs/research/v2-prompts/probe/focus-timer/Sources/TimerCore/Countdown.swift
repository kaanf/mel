import Foundation

/// A focus or break interval. Pure: the caller drives it with `tick(now:)`.
public struct Countdown: Sendable, Equatable {
    public enum Kind: String, Codable, Sendable { case focus, shortBreak, longBreak }
    public let kind: Kind
    public let length: Duration
    public private(set) var started: Date

    public init(kind: Kind, length: Duration, started: Date) {
        self.kind = kind; self.length = length; self.started = started
    }

    public func remaining(now: Date) -> Duration {
        max(.zero, length - .seconds(now.timeIntervalSince(started)))
    }

    public func isFinished(now: Date) -> Bool { remaining(now: now) == .zero }
}
