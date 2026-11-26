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
        try "mine".write(to: folder.appending(path: "ARCHITECTURE.md"), atomically: true, encoding: .utf8)
        #expect(SpecStore.existingFiles(in: folder) == [.architecture])

        try SpecStore.create(Spec(name: "Old", idea: "x", folder: folder))
        #expect(try String(contentsOf: folder.appending(path: "ARCHITECTURE.md"), encoding: .utf8) == "mine")
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
        spec.startBoard()
        await store.saveState(spec)
        spec.begin(.draft(.product))
        await store.saveState(spec)
        #expect(try SpecStore.loadState(in: spec.folder).stage == .discovery)

        try await Task.sleep(for: .milliseconds(200))
        #expect(try SpecStore.loadState(in: spec.folder) == spec)
    }

    @Test func flushWritesImmediately() async throws {
        var spec = try newSpec()
        let store = SpecStore(folder: spec.folder, debounce: .seconds(60))
        spec.startBoard()
        await store.saveState(spec)
        try await store.flushState()
        #expect(try SpecStore.loadState(in: spec.folder).stage == .board)
    }

    @Test func stateJSONUsesReadableKeys() throws {
        let spec = try newSpec()
        let json = try String(contentsOf: spec.folder.appending(path: ".mel/state.json"), encoding: .utf8)
        #expect(json.contains(#""product" : "locked""#))
    }

    // MARK: v2 layout

    private func v2Spec(_ slug: String = "booking") throws -> Spec {
        let spec = Spec(name: slug, idea: "x", size: .feature, folder: SpecStore.specFolder(slug: slug, project: parent))
        try SpecStore.create(spec)
        return spec
    }

    @Test func scanFindsEverySpecInTheProject() throws {
        let b = try v2Spec("booking")
        let a = try v2Spec("auth")
        try FileManager.default.createDirectory(at: parent.appending(path: "specs/empty"), withIntermediateDirectories: true)
        let found = SpecStore.scan(project: parent)
        #expect(found.map(\.id) == [a.id, b.id])
        #expect(found[0].project == Project(folder: parent).folder)
        #expect(SpecStore.scan(project: parent.appending(path: "nowhere")).isEmpty)
    }

    @Test func snapshotsAndDecisions() async throws {
        let folder = try v2Spec().folder
        let store = SpecStore(folder: folder)
        #expect(await store.snapshot(.requirements) == nil)
        try await store.saveSnapshot("# Requirements\n", for: .requirements)
        #expect(await store.snapshot(.requirements) == "# Requirements\n")
        #expect(FileManager.default.fileExists(atPath: folder.appending(path: ".mel/approved/REQUIREMENTS.md").path))

        #expect(await store.readDecisions().isEmpty)
        let d = Decision(id: "D-01", title: "Packs", reason: "From the idea.", source: "Discovery Q2", date: .now, affects: ["2.1"])
        try await store.writeDecisions([d])
        let read = await store.readDecisions()
        #expect(read.map(\.title) == ["Packs"])
        #expect(read.first?.affects == ["2.1"])
    }

    @Test func attachmentsGetFreeNames() async throws {
        let store = SpecStore(folder: try v2Spec().folder)
        let file = parent.appending(path: "crash.log")
        try "boom".write(to: file, atomically: true, encoding: .utf8)
        let first = try await store.attach(copying: file)
        let second = try await store.attach(copying: file)
        #expect(first.fileName == "crash.log")
        #expect(second.fileName == "crash 2.log")
        let log = try await store.attachLog("trace")
        #expect(log.fileName == "log-1.txt")
        #expect(try String(contentsOf: store.url(log), encoding: .utf8) == "trace")
        #expect(store.url(log).path.hasSuffix("/specs/booking/.mel/attachments/log-1.txt"))
        try await store.remove(first)
        #expect(!FileManager.default.fileExists(atPath: store.url(first).path))
    }

    @Test func taskPromptsReplaceTheFolder() async throws {
        let store = SpecStore(folder: try v2Spec().folder)
        let tasks = SpecTask.parse("- [ ] 1. One\n  - Covers: 1.1\n- [ ] 2. Two\n")
        let urls = try await store.writeTaskPrompts(tasks, requirements: "- 1.1 THE APP SHALL work.")
        #expect(urls.map(\.lastPathComponent) == ["task-01.md", "task-02.md"])
        #expect(try String(contentsOf: urls[0], encoding: .utf8).contains("- 1.1 THE APP SHALL work."))
        let again = try await store.writeTaskPrompts(Array(tasks.prefix(1)), requirements: "")
        #expect(again.count == 1)
        #expect(!FileManager.default.fileExists(atPath: urls[1].path))
    }
}
