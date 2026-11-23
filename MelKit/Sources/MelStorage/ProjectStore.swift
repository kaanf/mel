import Foundation
import MelSpec

/// Disk access for a project's own files (V2.md §3): `.mel/project/` and Mel's block in AGENTS.md.
public enum ProjectStore {
    /// `<project>/.mel/project/`.
    public static func contextFolder(project: URL) -> URL {
        project.appending(path: ".mel/project", directoryHint: .isDirectory)
    }

    /// The four context files, or nil until A3 has run.
    public static func readContext(project: URL) -> ProjectContext? { fatalError("stub") }

    public static func writeContext(_ context: ProjectContext, project: URL) throws { fatalError("stub") }

    /// A3 "Add Rule": appends a line to `principles.md`.
    public static func addRule(_ rule: String, project: URL) throws { fatalError("stub") }

    /// True for a folder with nothing but dotfiles: A3 picks "New project, no code yet".
    public static func isEmpty(project: URL) -> Bool { fatalError("stub") }

    /// Start from an Idea: creates `<parent>/<slug>/` and returns it.
    public static func createProject(name: String, parent: URL) throws -> URL { fatalError("stub") }
}
