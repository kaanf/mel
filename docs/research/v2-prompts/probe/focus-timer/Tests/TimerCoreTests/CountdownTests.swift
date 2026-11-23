import Testing
import Foundation
@testable import TimerCore

@Test func finishesAfterLength() {
    let start = Date(timeIntervalSince1970: 0)
    let c = Countdown(kind: .focus, length: .seconds(60), started: start)
    #expect(!c.isFinished(now: start.addingTimeInterval(59)))
    #expect(c.isFinished(now: start.addingTimeInterval(60)))
}
