import Foundation

/// The spec's conversation with the main model. Drafts, changes and rewrites resume it, so a file
/// it already holds is read from the prompt cache instead of being sent again: a prompt carries
/// only the files the conversation hasn't seen as they are now.
public struct Conversation: Codable, Hashable, Sendable {
    /// Claude Code's session ID, for `--resume`.
    public var id: String
    /// Each file as the conversation last saw it (its own draft, its own edits applied, or the text a
    /// prompt sent), by fingerprint.
    public var seen: [DocKind: UInt64] = [:]
    /// Characters sent and received so far.
    public var size = 0

    /// Past this many characters the next run starts a new conversation, well before Claude Code
    /// would compact it (a compacted conversation no longer holds the files word for word).
    public static let limit = 400_000

    public init(id: String) {
        self.id = id
    }

    /// The files of `kinds` the conversation hasn't seen as `documents` has them now.
    public func unseen(_ kinds: [DocKind], in documents: [DocKind: String]) -> [DocKind] {
        kinds.filter { seen[$0] != Self.fingerprint(documents[$0] ?? "") }
    }

    public mutating func saw(_ texts: [DocKind: String]) {
        for (kind, text) in texts { seen[kind] = Self.fingerprint(text) }
    }

    /// The next prompt sends these files again.
    public mutating func forget(_ kinds: some Sequence<DocKind>) {
        for kind in kinds { seen[kind] = nil }
    }

    /// FNV-1a over the UTF-8 bytes: stable across launches, unlike `Hasher`.
    static func fingerprint(_ text: String) -> UInt64 {
        text.utf8.reduce(14_695_981_039_346_656_037) { ($0 ^ UInt64($1)) &* 1_099_511_628_211 }
    }
}
