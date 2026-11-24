import Foundation
import Testing
import MelSpec
@testable import MelStorage

final class ProjectStoreTests {
    let parent = FileManager.default.temporaryDirectory.appending(path: "mel-tests-\(UUID().uuidString)", directoryHint: .isDirectory)

    deinit { try? FileManager.default.removeItem(at: parent) }

    @Test func contextRoundTripsAndRulesAppend() throws {
        let project = try ProjectStore.createProject(name: "Yoga Studio", parent: parent)
        #expect(project.lastPathComponent == "yoga-studio")
        #expect(ProjectStore.readContext(project: project) == nil)

        let context = ProjectContext(product: "# Product\n", tech: "# Tech\n", structure: "# Structure\n", principles: "# Principles\n\n- Small PRs\n",
                                     read: [ReadItem(label: "README.md", source: "Product summary")], sources: ["product.md": "From README"])
        try ProjectStore.writeContext(context, project: project)
        #expect(ProjectStore.readContext(project: project) == context)

        try ProjectStore.addRule("No new dependencies ", project: project)
        #expect(ProjectStore.readContext(project: project)?.principles == "# Principles\n\n- Small PRs\n- No new dependencies\n")
    }

    @Test func emptyFolderIgnoresDotfiles() throws {
        let project = try ProjectStore.createProject(name: "New", parent: parent)
        #expect(ProjectStore.isEmpty(project: project))
        try FileManager.default.createDirectory(at: project.appending(path: ".git"), withIntermediateDirectories: true)
        #expect(ProjectStore.isEmpty(project: project))
        try "x".write(to: project.appending(path: "main.swift"), atomically: true, encoding: .utf8)
        #expect(!ProjectStore.isEmpty(project: project))
    }

    @Test func newProjectNeverReusesAFolder() throws {
        let first = try ProjectStore.createProject(name: "Climbing Gym", parent: parent)
        let second = try ProjectStore.createProject(name: "Climbing Gym", parent: parent)
        #expect([first, second].map(\.lastPathComponent) == ["climbing-gym", "climbing-gym-2"])
    }
}
