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
    public var modules: [Module] { [] }

    /// Decodes the A3 run's JSON reply.
    public static func decode(_ reply: String) throws -> ProjectContext { fatalError("stub") }
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
    /// symlinks resolved (/tmp and /private/tmp agree), with a trailing slash.
    public var normalizedFolder: URL {
        URL(filePath: standardizedFileURL.resolvingSymlinksInPath().path(percentEncoded: false), directoryHint: .isDirectory)
    }
}
