import Foundation
import Testing
import MelSpec
@testable import MelStorage

final class SpecStoreTests {
    let parent = FileManager.default.temporaryDirectory.appending(path: "mel-tests-\(UUID().uuidString)", directoryHint: .isDirectory)

    deinit { try? FileManager.default.removeItem(at: parent) }

    private func newSpec() throws -> Spec {
        let spec = Spec(name: "Yoga Studio Booking", idea: "Book classes", folder: SpecStore.specsFolder(name: "Yoga Studio Booking", parent: parent))
        try SpecStore.create(spec)
        return spec
    }

    @Test(arguments: [
        ("Yoga Studio Booking", "yoga-studio-booking"),
        ("  Café — Menü 2.0! ", "cafe-menu-2-0"),
        ("日本", "spec"),
        ("", "spec"),
    ])
    func slug(name: String, expected: String) {
        #expect(SpecStore.slug(name) == expected)
    }

    @Test func createMakesFolderAndState() throws {
        let spec = try newSpec()
        #expect(spec.folder.path.hasSuffix("/yoga-studio-booking/specs"))
        #expect(try SpecStore.loadState(in: spec.folder) == spec)
        #expect(SpecStore.existingFiles(in: spec.folder).isEmpty)
    }

    @Test func existingFilesAreDetectedAndNotOverwrittenByCreate() throws {
        let folder = SpecStore.specsFolder(name: "Old", parent: parent)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try "mine".write(to: folder.appending(path: "DESIGN.md"), atomically: true, encoding: .utf8)
        #expect(SpecStore.existingFiles(in: folder) == [.design])

        try SpecStore.create(Spec(name: "Old", idea: "x", folder: folder))
        #expect(try String(contentsOf: folder.appending(path: "DESIGN.md"), encoding: .utf8) == "mine")
    }

    @Test func writeAndRead() async throws {
        let store = SpecStore(folder: try newSpec().folder)
        #expect(await store.read(.product) == nil)
        try await store.write("# Product\n", for: .product)
        try await store.write("# Tasks\n", for: .tasks)
        #expect(await store.read(.product) == "# Product\n")
        #expect(await store.readAll() == [.product: "# Product\n", .tasks: "# Tasks\n"])
    }

    @Test func stateWritesAreDebouncedToTheLatest() async throws {
        var spec = try newSpec()
        let store = SpecStore(folder: spec.folder, debounce: .milliseconds(50))
        spec.apply(.discoveryFinished)
        await store.saveState(spec)
        spec.apply(.draftFinished)
        await store.saveState(spec)
        #expect(try SpecStore.loadState(in: spec.folder).stage == .discovery)

        try await Task.sleep(for: .milliseconds(200))
        #expect(try SpecStore.loadState(in: spec.folder) == spec)
    }

    @Test func flushWritesImmediately() async throws {
        var spec = try newSpec()
        let store = SpecStore(folder: spec.folder, debounce: .seconds(60))
        spec.apply(.discoveryFinished)
        await store.saveState(spec)
        try await store.flushState()
        #expect(try SpecStore.loadState(in: spec.folder).stage == .drafting(.product))
    }

    @Test func stateJSONUsesReadableKeys() throws {
        let spec = try newSpec()
        let json = try String(contentsOf: spec.folder.appending(path: ".mel/state.json"), encoding: .utf8)
        #expect(json.contains(#""product" : "locked""#))
    }
}
