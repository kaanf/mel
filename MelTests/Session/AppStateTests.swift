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
        let expected = folder.appending(path: "yoga-studio/specs/yoga-studio", directoryHint: .isDirectory)
        let session = try app.createSpec(name: "Yoga Studio", idea: "Book classes.", size: .product, project: nil, parent: folder)
        #expect(session.spec.folder.standardizedFileURL.path == expected.standardizedFileURL.path)
        #expect(app.projects.map(\.name) == ["yoga-studio"])
        #expect(app.currentProject?.name == "yoga-studio")   // the sidebar follows the new folder
        #expect(app.selection == session.spec.id)
        #expect(FileManager.default.fileExists(atPath: expected.appending(path: ".mel/state.json").path))

        // The same name again gets a free slug in the same project.
        let second = try app.createSpec(name: "Yoga Studio", idea: "Again.", size: .feature, project: app.projects[0])
        #expect(second.spec.folder.lastPathComponent == "yoga-studio-2")
    }

    @Test func newSpecsTakeTheChosenLanguage() throws {
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let defaults = UserDefaults(suiteName: "mel-app-\(UUID().uuidString)")!
        let app = AppState(adapter: ClaudeCode(), makeRunner: { _ in fatalError() }, defaults: defaults)
        #expect(app.specLanguage == .english)
        app.specLanguage = .turkish
        let session = try app.createSpec(name: "Yoga Studio", idea: "Ders rezervasyonu.", size: .product, project: nil, parent: folder)
        #expect(session.spec.language == .turkish)
        #expect(AppState(adapter: ClaudeCode(), makeRunner: { _ in fatalError() }, defaults: defaults).specLanguage == .turkish)
    }

    /// 10.4: a model per step, saved; a choice from before 0.12 carries over to the steps it covered.
    @Test func modelsForEachStepCarryOverAndPersist() {
        let defaults = UserDefaults(suiteName: "mel-app-\(UUID().uuidString)")!
        defaults.set(AgentModel.sonnet.rawValue, forKey: "writingModel")
        let app = AppState(adapter: ClaudeCode(), makeRunner: { _ in fatalError() }, defaults: defaults)
        #expect(app.model(for: .tasks) == .sonnet)
        #expect(app.model(for: .changes) == .sonnet)
        #expect(app.model(for: .checks) == .sonnet)
        #expect(app.model(for: .building) == .sonnet)
        app.models[.architecture] = .haiku
        #expect(AppState(adapter: ClaudeCode(), makeRunner: { _ in fatalError() }, defaults: defaults).model(for: .architecture) == .haiku)
        #expect(ModelStep(.requirements) == .productFiles)
    }

    @Test func ideaSpecsGoUnderDeveloperAndTakeIntakesName() throws {
        let app = AppState(adapter: ClaudeCode(), makeRunner: { _ in fatalError() }, defaults: UserDefaults(suiteName: "mel-app-\(UUID().uuidString)")!)
        app.developerFolder = folder.appending(path: "Developer", directoryHint: .isDirectory)
        let first = try app.createSpec(name: Spec.untitledName, idea: "Climbing gym.", size: .product, project: nil)
        let second = try app.createSpec(name: Spec.untitledName, idea: "Bakery.", size: .product, project: nil)
        #expect(app.projects.map(\.name) == ["untitled-spec", "untitled-spec-2"])
        #expect(first.spec.project.deletingLastPathComponent().lastPathComponent == "Developer")

        // The idea's project folder moves with the spec; the other project stays.
        let folder = try app.rename(second.spec.id, to: "Bakery Orders")
        #expect(folder.path.hasSuffix("/Developer/bakery-orders/specs/bakery-orders"))
        #expect(FileManager.default.fileExists(atPath: folder.appending(path: ".mel/state.json").path))
        #expect(app.projects.map(\.name) == ["untitled-spec", "bakery-orders"])
        #expect(app.specs.map(\.name) == [Spec.untitledName, "Bakery Orders"])
        #expect(app.specs(in: app.projects[1]).count == 1)

        // A spec in a project the user added keeps the project folder.
        let added = try app.createSpec(name: Spec.untitledName, idea: "Fix.", size: .feature, project: app.projects[1])
        let renamed = try app.rename(added.spec.id, to: "Bakery Orders")
        #expect(renamed.path.hasSuffix("/bakery-orders/specs/bakery-orders-2"))
        #expect(app.projects.map(\.name) == ["untitled-spec", "bakery-orders"])
    }

    @Test func currentProjectIsRememberedAndRulesAreEdited() throws {
        let defaults = UserDefaults(suiteName: "mel-app-\(UUID().uuidString)")!
        let app = AppState(adapter: ClaudeCode(), makeRunner: { _ in fatalError() }, defaults: defaults)
        var projects: [Project] = []
        for name in ["yoga", "bakery"] {
            let folder = folder.appending(path: name, directoryHint: .isDirectory)
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            projects.append(try app.addProject(folder))
        }
        #expect(app.currentProject == projects[0])
        app.projectID = projects[1].id
        #expect(AppState(adapter: ClaudeCode(), makeRunner: { _ in fatalError() }, defaults: defaults).currentProject?.name == "bakery")

        try app.addRule("No new dependency without a reason.", to: projects[1])
        try app.addRule("Every check gets a test.", to: projects[1])
        #expect(app.contexts[projects[1].id]?.rules == ["No new dependency without a reason.", "Every check gets a test."])
        try app.removeRule("No new dependency without a reason.", from: projects[1])
        #expect(app.contexts[projects[1].id]?.rules == ["Every check gets a test."])

        app.removeProject(projects[1])
        #expect(app.currentProject == projects[0])
    }

    @Test func addedProjectKnowsItsBranch() throws {
        let git = folder.appending(path: "yoga/.git", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: git, withIntermediateDirectories: true)
        try "ref: refs/heads/waitlist\n".write(to: git.appending(path: "HEAD"), atomically: true, encoding: .utf8)
        let app = AppState(adapter: ClaudeCode(), makeRunner: { _ in fatalError() }, defaults: UserDefaults(suiteName: "mel-app-\(UUID().uuidString)")!)
        let project = try app.addProject(git.deletingLastPathComponent())
        #expect(app.branches[project.id] == "waitlist")
        app.removeProject(project)
        #expect(app.branches.isEmpty)
    }
}
