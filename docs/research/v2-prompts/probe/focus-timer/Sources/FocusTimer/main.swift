import Foundation
import TimerCore
import SessionStore

let store = Store(folder: URL.applicationSupportDirectory.appending(path: "FocusTimer"))
switch CommandLine.arguments.dropFirst().first {
case "start":
    let countdown = Countdown(kind: .focus, length: .seconds(25 * 60), started: .now)
    while !countdown.isFinished(now: .now) { sleep(1) }
    try store.append(Session(kind: .focus, start: countdown.started, end: .now))
    print("Done. Take a break.")
case "log":
    for s in try store.load(day: .now) { print(s.kind.rawValue, s.start.formatted(date: .omitted, time: .shortened)) }
default:
    print("usage: focus start | log")
}
