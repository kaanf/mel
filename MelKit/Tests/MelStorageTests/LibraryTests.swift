import Foundation
import Testing
@testable import MelStorage

final class LibraryTests {
    let suite = "mel-tests-\(UUID().uuidString)"
    let root = FileManager.default.temporaryDirectory.appending(path: "mel-library-\(UUID().uuidString)", directoryHint: .isDirectory)
    let library: Library

    init() {
        library = Library(defaults: UserDefaults(suiteName: suite)!)
    }

    deinit {
        UserDefaults().removePersistentDomain(forName: suite)
        try? FileManager.default.removeItem(at: root)
    }

    private func makeFolder(_ name: String) throws -> URL {
        let url = root.appending(path: name, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    /// Bookmarks resolve to `/private/var/…`; compare paths with symlinks resolved.
    private func path(_ url: URL) -> String { url.resolvingSymlinksInPath().path }

    @Test func emptyByDefault() {
        #expect(library.load().isEmpty)
    }

    @Test func keepsOrder() throws {
        let a = try makeFolder("a/specs"), b = try makeFolder("b/specs")
        library.save([b, a])
        #expect(library.load().map { path($0.folder) } == [path(b), path(a)])
        #expect(library.load().allSatisfy { !$0.isMissing })
    }

    @Test func followsAMovedFolder() throws {
        let old = try makeFolder("old")
        library.save([old])
        let new = root.appending(path: "new", directoryHint: .isDirectory)
        try FileManager.default.moveItem(at: old, to: new)
        let item = try #require(library.load().first)
        #expect(!item.isMissing)
        #expect(path(item.folder) == path(new))
    }

    @Test func deletedFolderIsMissing() throws {
        let gone = try makeFolder("gone")
        library.save([gone])
        try FileManager.default.removeItem(at: gone)
        let item = try #require(library.load().first)
        #expect(item.isMissing)
        #expect(path(item.folder) == path(gone))
    }
}
