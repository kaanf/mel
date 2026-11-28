import Foundation
import MelSpec

/// Disk access for a project's own files (V2.md §3): `.mel/project/`. Every write is atomic.
public enum ProjectStore {
    /// `<project>/.mel/project/`.
    public static func contextFolder(project: URL) -> URL {
        project.appending(path: ".mel/project", directoryHint: .isDirectory)
    }

    /// The four context files, or nil until A3 has run. A missing file reads as empty.
    public static func readContext(project: URL) -> ProjectContext? {
        let folder = contextFolder(project: project)
        guard FileManager.default.fileExists(atPath: folder.path) else { return nil }
        let texts = ProjectContext.fileNames.map { (try? String(contentsOf: folder.appending(path: $0), encoding: .utf8)) ?? "" }
        let meta = (try? Data(contentsOf: folder.appending(path: metaFile))).flatMap { try? JSONDecoder().decode(Meta.self, from: $0) }
        return ProjectContext(product: texts[0], tech: texts[1], structure: texts[2], principles: texts[3], read: meta?.read ?? [], sources: meta?.sources ?? [:])
    }

    public static func writeContext(_ context: ProjectContext, project: URL) throws {
        let folder = contextFolder(project: project)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        for (name, text) in zip(ProjectContext.fileNames, [context.product, context.tech, context.structure, context.principles]) {
            try Data(text.utf8).write(to: folder.appending(path: name), options: .atomic)
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(Meta(read: context.read, sources: context.sources)).write(to: folder.appending(path: metaFile), options: .atomic)
    }

    /// A3's "What Mel read" rows and card state words, next to the four files.
    private static let metaFile = "context.json"

    private struct Meta: Codable {
        var read: [ReadItem]
        var sources: [String: String]
    }

    /// Settings › Specs "Add Rule": appends `- rule` to `principles.md`.
    public static func addRule(_ rule: String, project: URL) throws {
        let url = contextFolder(project: project).appending(path: "principles.md")
        var text = (try? String(contentsOf: url, encoding: .utf8)) ?? "# Principles\n"
        while text.last?.isNewline == true { text.removeLast() }
        text += "\n- \(rule.trimmingCharacters(in: .whitespacesAndNewlines))\n"
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(text.utf8).write(to: url, options: .atomic)
    }

    /// Settings › Specs: takes the first `- rule` line with this text out of `principles.md`.
    public static func removeRule(_ rule: String, project: URL) throws {
        let url = contextFolder(project: project).appending(path: "principles.md")
        var lines = try String(contentsOf: url, encoding: .utf8).split(omittingEmptySubsequences: false, whereSeparator: \.isNewline).map(String.init)
        guard let i = lines.firstIndex(of: "- \(rule)") else { return }
        lines.remove(at: i)
        try Data(lines.joined(separator: "\n").utf8).write(to: url, options: .atomic)
    }

    // MARK: The project spec (`specs/current/`, OQ #45)

    public static func projectSpecFolder(project: URL) -> URL {
        project.appending(path: "specs/current", directoryHint: .isDirectory)
    }

    /// Every area file in `specs/current/`, or nil when the folder isn't there.
    public static func readProjectSpec(project: URL) -> ProjectSpec? {
        let folder = projectSpecFolder(project: project)
        guard let names = try? FileManager.default.contentsOfDirectory(atPath: folder.path(percentEncoded: false)) else { return nil }
        let areas = names.filter { $0.hasSuffix(".md") }.compactMap { name in
            (try? String(contentsOf: folder.appending(path: name), encoding: .utf8)).flatMap { ProjectSpec.area(file: name, text: $0) }
        }
        return ProjectSpec(areas: areas)
    }

    /// Writes the areas of `files` (all when nil); an area with no rules left is removed.
    public static func writeProjectSpec(_ spec: ProjectSpec, files: Set<String>? = nil, project: URL) throws {
        let folder = projectSpecFolder(project: project)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        for area in spec.areas where files?.contains(area.file) ?? true {
            try Data(area.markdown.utf8).write(to: folder.appending(path: area.file), options: .atomic)
        }
    }

    /// Undo: each file back as it was (nil: it didn't exist).
    public static func restoreProjectSpec(_ texts: [String: String?], project: URL) throws {
        let folder = projectSpecFolder(project: project)
        for (name, text) in texts {
            let url = folder.appending(path: name)
            if let text { try Data(text.utf8).write(to: url, options: .atomic) } else { try? FileManager.default.removeItem(at: url) }
        }
    }

    /// True for a folder with nothing but dotfiles: there is no code to read yet.
    public static func isEmpty(project: URL) -> Bool {
        let items = (try? FileManager.default.contentsOfDirectory(atPath: project.path)) ?? []
        return items.allSatisfy { $0.hasPrefix(".") }
    }

    /// Start from an Idea: creates `<parent>/<slug>/` (`<slug>-2`… if taken) and returns it.
    public static func createProject(name: String, parent: URL) throws -> URL {
        let folder = SpecStore.freeFolder(name: name, in: parent)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder.normalizedFolder
    }
}
