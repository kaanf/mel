import Foundation

/// `.mel/project/`: written once by A3, included in every later prompt (V2.md §5).
public struct ProjectContext: Codable, Hashable, Sendable {
    public var product: String
    public var tech: String
    public var structure: String
    public var principles: String
    /// A3 "What Mel read": the run's reading list, kept in `.mel/project/context.json`.
    public var read: [ReadItem]
    /// A3 card state words per file ("product.md": "From README"), kept in `.mel/project/context.json`.
    public var sources: [String: String]

    public init(product: String, tech: String, structure: String, principles: String, read: [ReadItem] = [], sources: [String: String] = [:]) {
        self.product = product
        self.tech = tech
        self.structure = structure
        self.principles = principles
        self.read = read
        self.sources = sources
    }

    /// `read` and `sources` may be missing from a reply.
    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        product = try c.decode(String.self, forKey: .product)
        tech = try c.decode(String.self, forKey: .tech)
        structure = try c.decode(String.self, forKey: .structure)
        principles = try c.decode(String.self, forKey: .principles)
        read = try c.decodeIfPresent([ReadItem].self, forKey: .read) ?? []
        sources = try c.decodeIfPresent([String: String].self, forKey: .sources) ?? [:]
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
                var name = line[line.index(line.startIndex, offsetBy: 2)..<dash.lowerBound].trimming(while: \.isWhitespace)
                // "FocusTimer (executable CLI)" → "FocusTimer".
                if name.hasSuffix(")"), let open = name.lastIndex(of: "(") { name = name[..<open].trimming(while: \.isWhitespace) }
                modules.append(Module(name: String(name),
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

/// One "What Mel read" row: "README.md" · "Product summary".
public struct ReadItem: Codable, Hashable, Sendable {
    public var label: String
    public var source: String

    public init(label: String, source: String) {
        self.label = label
        self.source = source
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

/// A2: a git repo found one level under `~/Developer`, with its meta line ("Kotlin · edited today").
public struct FoundRepository: Identifiable, Hashable, Sendable {
    public var url: URL
    public var language: String?
    public var modified: Date?
    public var id: URL { url }

    public init(url: URL, language: String? = nil, modified: Date? = nil) {
        self.url = url
        self.language = language
        self.modified = modified
    }
}
