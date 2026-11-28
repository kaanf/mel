import Foundation

/// A change run's reply: `Patch` edits across the written files (Tell Mel, card answers, Update,
/// Remove). Mel applies them; everything outside the edits stays word for word.
public struct Change: Codable, Hashable, Sendable {
    public var edits: [Edit]

    public struct Edit: Codable, Hashable, Sendable {
        public var file: DocKind
        public var old: String
        public var new: String

        public init(file: DocKind, old: String, new: String) {
            self.file = file
            self.old = old
            self.new = new
        }

        /// `file` as `requirements` or `REQUIREMENTS.md`.
        public init(from decoder: any Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            let name = try c.decode(String.self, forKey: .file).lowercased()
            guard let file = DocKind(rawValue: name.hasSuffix(".md") ? String(name.dropLast(3)) : name) else {
                throw DecodingError.dataCorruptedError(forKey: .file, in: c, debugDescription: "Unknown file \(name).")
            }
            self.file = file
            old = try c.decode(String.self, forKey: .old)
            new = try c.decode(String.self, forKey: .new)
        }
    }

    public init(edits: [Edit]) {
        self.edits = edits
    }

    /// The files it changes, in the order given.
    public func files(in order: [DocKind]) -> [DocKind] { order.filter { kind in edits.contains { $0.file == kind } } }

    private func patch(for kind: DocKind) -> Patch {
        Patch(edits: edits.filter { $0.file == kind }.map { Patch.Edit(old: $0.old, new: $0.new) })
    }

    /// The files where an edit can't be placed, or that aren't in `documents`. Empty: `apply` works.
    public func unplaced(in documents: [DocKind: String]) -> [DocKind] {
        DocKind.allCases.filter { kind in
            edits.contains { $0.file == kind } && documents[kind].flatMap(patch(for: kind).apply) == nil
        }
    }

    /// The new text of each changed file, or nil when an edit can't be placed: then nothing is applied (OQ #25).
    public func apply(to documents: [DocKind: String]) -> [DocKind: String]? {
        var result: [DocKind: String] = [:]
        for kind in DocKind.allCases where edits.contains(where: { $0.file == kind }) {
            guard let text = documents[kind].flatMap(patch(for: kind).apply) else { return nil }
            result[kind] = text
        }
        return result
    }

    /// Without the edits of `files`, which are rewritten whole instead.
    public func without(_ files: [DocKind]) -> Change {
        Change(edits: edits.filter { !files.contains($0.file) })
    }

    /// "Changed 2 places in REQUIREMENTS.md, 1 in ARCHITECTURE.md".
    public func summary(order: [DocKind]) -> String {
        let counts = files(in: order).map { kind in (kind, edits.count { $0.file == kind }) }
        guard let first = counts.first else { return "Nothing needed to change" }
        let rest = counts.dropFirst().map { "\($0.1) in \($0.0.fileName)" }
        return (["Changed \(first.1) \(first.1 == 1 ? "place" : "places") in \(first.0.fileName)"] + rest).joined(separator: ", ")
    }

    /// V2-26: the heading of the section an edit lands in ("3. Cancelling"), read from the file after
    /// the change; "new" when the edit adds a section of its own. Nil when the file has no heading above it.
    public static func section(of edit: Edit, in text: String) -> String? {
        let anchor = edit.new.isEmpty ? edit.old : edit.new
        guard !anchor.isEmpty, let range = text.range(of: anchor) else { return nil }
        let before = text[..<range.lowerBound]
        let ownHeading = anchor.split(separator: "\n").first.map { $0.hasPrefix("#") } ?? false
        if ownHeading, let line = anchor.split(separator: "\n").first { return heading(line) + " · new" }
        guard let line = before.split(separator: "\n").last(where: { $0.hasPrefix("#") }) else { return nil }
        return heading(line)
    }

    private static func heading(_ line: Substring) -> String {
        String(line.drop { $0 == "#" }).trimmingCharacters(in: .whitespaces)
    }

    /// Decodes the JSON object in `reply`; text around it is ignored.
    public static func decode(_ reply: String) throws -> Change {
        try JSONDecoder().decode(Change.self, from: jsonObject(in: reply))
    }
}
