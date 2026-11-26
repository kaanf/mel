import Foundation

/// A revise reply (OQ #25): passages to replace in one file. Mel holds the rest of the file,
/// so it stays word for word.
public struct Patch: Codable, Hashable, Sendable {
    public var edits: [Edit]

    public struct Edit: Codable, Hashable, Sendable {
        public var old: String
        public var new: String

        public init(old: String, new: String) {
            self.old = old
            self.new = new
        }
    }

    public init(edits: [Edit]) {
        self.edits = edits
    }

    /// `text` with the edits applied in order, or nil when one can't be placed: its `old` must
    /// occur exactly once, character for character. Nothing is applied in part.
    public func apply(to text: String) -> String? {
        var result = text
        for edit in edits {
            guard let range = result.range(of: edit.old, options: .literal),
                  result[result.index(after: range.lowerBound)...].range(of: edit.old, options: .literal) == nil else { return nil }
            result.replaceSubrange(range, with: edit.new)
        }
        return result
    }

    /// Decodes the JSON object in `reply`; text around it is ignored.
    public static func decode(_ reply: String) throws -> Patch {
        try JSONDecoder().decode(Patch.self, from: jsonObject(in: reply))
    }
}
