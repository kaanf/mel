import Foundation

/// `.mel/project/`: written once by A3, included in every later prompt (V2.md §5).
public struct ProjectContext: Codable, Hashable, Sendable {
    public var product: String
    public var tech: String
    public var structure: String
    public var principles: String

    public init(product: String, tech: String, structure: String, principles: String) {
        self.product = product
        self.tech = tech
        self.structure = structure
        self.principles = principles
    }

    public static let fileNames = ["product.md", "tech.md", "structure.md", "principles.md"]

    /// `structure.md`'s `## Modules` list (`- Name — path`): B1's "Builds on" chips.
    public var modules: [Module] {
        var inModules = false
        var modules: [Module] = []
        for line in structure.split(whereSeparator: \.isNewline) {
            if line.hasPrefix("## ") {
                inModules = line.dropFirst(3).trimming(while: \.isWhitespace) == "Modules"
            } else if inModules, line.hasPrefix("- "), let dash = line.range(of: " — ") {
                modules.append(Module(name: String(line[line.index(line.startIndex, offsetBy: 2)..<dash.lowerBound]),
                                      path: String(line[dash.upperBound...].trimming(while: { $0.isWhitespace || $0 == "`" }))))
            }
        }
        return modules
    }

    /// Decodes the A3 run's JSON reply: `{"product": …, "tech": …, "structure": …, "principles": …}`.
    public static func decode(_ reply: String) throws -> ProjectContext {
        try JSONDecoder().decode(ProjectContext.self, from: jsonObject(in: reply))
    }

    /// Every later prompt's `{{project}}`.
    public var promptText: String {
        zip(Self.fileNames, [product, tech, structure, principles])
            .map { "### .mel/project/\($0)\n\n\($1.trimmingCharacters(in: .whitespacesAndNewlines))" }
            .joined(separator: "\n\n")
    }
}

public struct Module: Codable, Hashable, Sendable {
    public var name: String
    public var path: String

    public init(name: String, path: String) {
        self.name = name
        self.path = path
    }
}

/// A library entry: a folder, usually a git repo. Its specs are in `specs/*/`.
public struct Project: Identifiable, Hashable, Sendable {
    public var folder: URL        // last known location when missing
    public var isMissing: Bool
    /// `.mel/project/` exists (A3 has run).
    public var hasContext: Bool
    public var id: URL { folder }
    public var name: String { folder.lastPathComponent }

    public init(folder: URL, isMissing: Bool = false, hasContext: Bool = false) {
        self.folder = folder.normalizedFolder
        self.isMissing = isMissing
        self.hasContext = hasContext
    }
}

extension URL {
    /// One form for a folder, so project URLs compare and key dictionaries reliably: standardized,
    /// with a trailing slash. No disk access: bookmarks and pickers already give real paths.
    public var normalizedFolder: URL {
        URL(filePath: standardizedFileURL.path(percentEncoded: false), directoryHint: .isDirectory)
    }
}
