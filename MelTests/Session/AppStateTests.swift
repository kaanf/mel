import Foundation
import Testing
import MelAgent
import MelSpec
import MelStorage
@testable import Mel

@MainActor
struct AppStateTests {
    let folder = FileManager.default.temporaryDirectory.appending(path: "mel-app-\(UUID().uuidString)", directoryHint: .isDirectory)

    private func makeApp() -> AppState {
        AppState.preview([], agent: .missing)
    }

    @Test func previewSelectsFirstSpec() {
        let spec = Spec(name: "Yoga", idea: "Book classes", folder: URL(filePath: "/tmp/yoga/specs"), stage: .discovery, docs: [:], questions: [], coverage: [])
        let state = AppState.preview([spec], agent: .missing)
        #expect(state.selection == spec.id)
        #expect(state.session(for: spec.id).spec == spec)
    }

    @Test func findRepositoriesListsGitFoldersWithTheirLanguage() async throws {
        for (name, file) in [("yoga", "Package.swift"), ("site", "package.json"), ("notes", "README.md")] {
            let repo = folder.appending(path: name, directoryHint: .isDirectory)
            try FileManager.default.createDirectory(at: repo, withIntermediateDirectories: true)
            try "".write(to: repo.appending(path: file), atomically: true, encoding: .utf8)
            if name != "notes" { try FileManager.default.createDirectory(at: repo.appending(path: ".git"), withIntermediateDirectories: true) }
        }
        let app = makeApp()
        app.developerFolder = folder
        await app.findRepositories()
        #expect(app.foundRepositories.map(\.url.lastPathComponent) == ["site", "yoga"])
        #expect(app.foundRepositories.map(\.language) == ["JavaScript", "Swift"])
    }

    @Test func specWithoutProjectMakesOneUnderTheParent() throws {
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let app = AppState(adapter: ClaudeCode(), makeRunner: { _ in fatalError() }, defaults: UserDefaults(suiteName: "mel-app-\(UUID().uuidString)")!)
        let expected = app.specFolder(name: "Yoga Studio", size: .product, project: nil, parent: folder)
        let session = try app.createSpec(name: "Yoga Studio", idea: "Book classes.", size: .product, project: nil, parent: folder)
        #expect(session.spec.folder.standardizedFileURL.path == expected.standardizedFileURL.path)
        #expect(expected.path.hasSuffix("/yoga-studio/specs/yoga-studio"))
        #expect(app.projects.map(\.name) == ["yoga-studio"])
        #expect(app.selection == session.spec.id)
        #expect(FileManager.default.fileExists(atPath: expected.appending(path: ".mel/state.json").path))

        // The same name again gets a free slug in the same project.
        let second = try app.createSpec(name: "Yoga Studio", idea: "Again.", size: .feature, project: app.projects[0])
        #expect(second.spec.folder.lastPathComponent == "yoga-studio-2")
    }
}
