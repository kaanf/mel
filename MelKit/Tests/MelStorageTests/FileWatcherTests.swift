import Foundation
import Synchronization
import Testing
import MelSpec
@testable import MelStorage

final class FileWatcherTests {
    let folder = FileManager.default.temporaryDirectory.appending(path: "mel-watch-\(UUID().uuidString)", directoryHint: .isDirectory)
    let changes = Changes()

    init() throws {
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try "# Product\n".write(to: url(.product), atomically: true, encoding: .utf8)
    }

    deinit { try? FileManager.default.removeItem(at: folder) }

    private func url(_ kind: DocKind) -> URL { folder.appending(path: kind.fileName) }

    private func watch() -> FileWatcher {
        FileWatcher(folder: folder) { [changes] kind, text in changes.list.withLock { $0.append("\(kind.rawValue): \(text)") } }
    }

    /// The changes reported so far, once there are `count` of them or `seconds` have passed.
    private func reported(_ count: Int, within seconds: Double = 3) async -> [String] {
        let deadline = ContinuousClock.now + .seconds(seconds)
        while changes.list.withLock({ $0.count }) < count, ContinuousClock.now < deadline {
            try? await Task.sleep(for: .milliseconds(20))
        }
        return changes.list.withLock { $0 }
    }

    @Test func reportsAtomicAndInPlaceEdits() async throws {
        let watcher = watch()
        try "# Product\nAtomic\n".write(to: url(.product), atomically: true, encoding: .utf8)
        #expect(await reported(1) == ["product: # Product\nAtomic\n"])

        let handle = try FileHandle(forWritingTo: url(.product))
        try handle.seekToEnd()
        try handle.write(contentsOf: Data("In place\n".utf8))
        try handle.close()
        #expect(await reported(2).last == "product: # Product\nAtomic\nIn place\n")

        try "# Tasks\n".write(to: url(.tasks), atomically: true, encoding: .utf8)
        #expect(await reported(3).last == "tasks: # Tasks\n")
        withExtendedLifetime(watcher) {}
    }

    @Test func ownWritesAreSkipped() async throws {
        let watcher = watch()
        watcher.noteWritten("# Product\nMine\n", for: .product)
        try "# Product\nMine\n".write(to: url(.product), atomically: true, encoding: .utf8)
        #expect(await reported(1, within: 1).isEmpty)
        withExtendedLifetime(watcher) {}
    }

    @Test func checkBeforeOwnWriteLandsReportsNothing() async throws {
        let watcher = watch()
        watcher.noteWritten("# Product\nMine\n", for: .product)
        watcher.check()                                   // file still has the old text
        try "# Product\nMine\n".write(to: url(.product), atomically: true, encoding: .utf8)
        watcher.check()
        #expect(changes.list.withLock { $0 }.isEmpty)

        // The live stream may report this first; either way it's reported once.
        try "# Product\nTheirs\n".write(to: url(.product), atomically: true, encoding: .utf8)
        watcher.check()
        #expect(await reported(1) == ["product: # Product\nTheirs\n"])
    }

    @Test func rapidOwnWritesAreSkipped() async throws {
        let watcher = watch()
        watcher.noteWritten("one", for: .product)
        try "one".write(to: url(.product), atomically: true, encoding: .utf8)
        watcher.noteWritten("two", for: .product)
        watcher.check()                                   // sees the older own write
        watcher.noteWritten("three", for: .product)
        try "three".write(to: url(.product), atomically: true, encoding: .utf8)
        watcher.check()                                   // "two" never landed
        #expect(changes.list.withLock { $0 }.isEmpty)

        // An external edit back to a text Mel wrote earlier is still reported.
        try "two".write(to: url(.product), atomically: true, encoding: .utf8)
        watcher.check()
        #expect(await reported(1) == ["product: two"])
    }

    @Test func ownWriteEqualToTheFileDoesNotHideALaterEdit() async throws {
        let watcher = watch()
        watcher.noteWritten("# Product\n", for: .product)   // same as the file: nothing to wait for
        try "# Product\nTheirs\n".write(to: url(.product), atomically: true, encoding: .utf8)
        watcher.check()
        try "# Product\n".write(to: url(.product), atomically: true, encoding: .utf8)
        watcher.check()
        #expect(await reported(2) == ["product: # Product\nTheirs\n", "product: # Product\n"])
    }

    @Test func otherFilesAreIgnored() async throws {
        let watcher = watch()
        try FileManager.default.createDirectory(at: folder.appending(path: ".mel"), withIntermediateDirectories: true)
        try "{}".write(to: folder.appending(path: ".mel/state.json"), atomically: true, encoding: .utf8)
        try "notes".write(to: folder.appending(path: "NOTES.md"), atomically: true, encoding: .utf8)
        #expect(await reported(1, within: 1).isEmpty)
        withExtendedLifetime(watcher) {}
    }

    @Test func resolve() {
        #expect(FileWatcher.resolve(fileText: "new", editorText: "old", savedText: "old") == .reload("new"))
        #expect(FileWatcher.resolve(fileText: "new", editorText: "typing", savedText: "old") == .conflict(fileText: "new"))
    }
}

final class Changes: Sendable {
    let list = Mutex<[String]>([])
}
