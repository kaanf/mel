import Foundation
import MelSpec

/// Disk access for one spec folder (`<parent>/<slug>/specs`). Every write is atomic.
/// `state.json` is written at most once per `debounce`, with the latest `Spec`.
public actor SpecStore {
    public let folder: URL
    private let debounce: Duration
    private var pendingState: Spec?
    private var stateTask: Task<Void, Never>?

    public init(folder: URL, debounce: Duration = .milliseconds(500)) {
        self.folder = folder
        self.debounce = debounce
    }

    // MARK: Creating a spec

    /// "Yoga Studio Booking" → "yoga-studio-booking".
    public static func slug(_ name: String) -> String {
        let folded = name.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil).lowercased()
        let words = folded.split(whereSeparator: { !($0.isASCII && ($0.isLetter || $0.isNumber)) })
        return words.isEmpty ? "spec" : words.joined(separator: "-")
    }

    /// `<parent>/<slug>/specs`.
    public static func specsFolder(name: String, parent: URL) -> URL {
        parent.appending(path: slug(name), directoryHint: .isDirectory).appending(path: "specs", directoryHint: .isDirectory)
    }

    /// The spec files already in `folder`. The UI asks before using a folder where this isn't empty.
    public static func existingFiles(in folder: URL) -> [DocKind] {
        DocKind.allCases.filter { FileManager.default.fileExists(atPath: folder.appending(path: $0.fileName).path) }
    }

    /// Creates `spec.folder` (and `.mel/`) and writes `state.json`. Never touches existing spec files.
    public static func create(_ spec: Spec) throws {
        try FileManager.default.createDirectory(at: stateURL(in: spec.folder).deletingLastPathComponent(), withIntermediateDirectories: true)
        try writeState(spec, in: spec.folder)
    }

    // MARK: Files

    public func read(_ kind: DocKind) -> String? {
        try? String(contentsOf: url(kind), encoding: .utf8)
    }

    public func readAll() -> [DocKind: String] {
        var documents: [DocKind: String] = [:]
        for kind in DocKind.allCases { documents[kind] = read(kind) }
        return documents
    }

    public func write(_ text: String, for kind: DocKind) throws {
        try Data(text.utf8).write(to: url(kind), options: .atomic)
    }

    public nonisolated func url(_ kind: DocKind) -> URL {
        folder.appending(path: kind.fileName)
    }

    // MARK: State

    public static func loadState(in folder: URL) throws -> Spec {
        try JSONDecoder().decode(Spec.self, from: Data(contentsOf: stateURL(in: folder)))
    }

    /// Schedules a write of `spec`; calls within the debounce window coalesce into one write.
    public func saveState(_ spec: Spec) {
        pendingState = spec
        guard stateTask == nil else { return }
        stateTask = Task {
            try? await Task.sleep(for: debounce)
            try? flushState()
        }
    }

    /// Writes a pending state now (e.g. before quitting).
    public func flushState() throws {
        stateTask?.cancel()
        stateTask = nil
        guard let spec = pendingState else { return }
        pendingState = nil
        try Self.writeState(spec, in: folder)
    }

    private static func stateURL(in folder: URL) -> URL {
        folder.appending(path: ".mel", directoryHint: .isDirectory).appending(path: "state.json")
    }

    private static func writeState(_ spec: Spec, in folder: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(spec).write(to: stateURL(in: folder), options: .atomic)
    }
}
