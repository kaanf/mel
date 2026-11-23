import Foundation

/// The project folders (v1: spec folders) in sidebar order, kept in `UserDefaults` as bookmarks so they follow
/// the folder when it's moved. A folder that's gone (or in the Trash) comes back as missing.
public struct Library {
    public struct Item: Hashable, Sendable {
        public var folder: URL        // last known location when missing
        public var isMissing: Bool
    }

    private struct Entry: Codable {
        var bookmark: Data?
        var path: String
    }

    private let defaults: UserDefaults
    private let key: String

    public init(defaults: UserDefaults = .standard, key: String = "library") {
        self.defaults = defaults
        self.key = key
    }

    public func load() -> [Item] {
        guard let data = defaults.data(forKey: key), let entries = try? JSONDecoder().decode([Entry].self, from: data) else { return [] }
        return entries.map { entry in
            var stale = false
            let folder = entry.bookmark.flatMap { try? URL(resolvingBookmarkData: $0, bookmarkDataIsStale: &stale) }
                ?? URL(filePath: entry.path, directoryHint: .isDirectory)
            let exists = FileManager.default.fileExists(atPath: folder.path)
            return Item(folder: folder, isMissing: !exists || folder.path.contains("/.Trash/"))
        }
    }

    /// Replaces the stored list. Call after adding, removing, reordering or locating a folder.
    public func save(_ folders: [URL]) {
        let entries = folders.map { Entry(bookmark: try? $0.bookmarkData(), path: $0.path) }
        defaults.set(try? JSONEncoder().encode(entries), forKey: key)
    }
}
