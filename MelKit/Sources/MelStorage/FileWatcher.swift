import CoreServices
import Foundation
import MelSpec
import Synchronization

/// Watches the four spec files in a folder and reports text that differs from what it last saw,
/// whether an editor saved in place or atomically. Mel's own writes are skipped by calling
/// `noteWritten` before writing. `onChange` runs on a background queue.
public final class FileWatcher: Sendable {
    /// What to do with an external edit (UI shows Keep Mine / Use File for `conflict`).
    public enum Resolution: Hashable, Sendable {
        case reload(String)
        case conflict(fileText: String)
    }

    private let folder: URL
    private let known: Mutex<[DocKind: String]>
    private let onChange: @Sendable (DocKind, String) -> Void
    private let queue = DispatchQueue(label: "mel.filewatcher")
    nonisolated(unsafe) private var stream: FSEventStreamRef?

    public init(folder: URL, onChange: @escaping @Sendable (DocKind, String) -> Void) {
        self.folder = folder
        self.onChange = onChange
        known = Mutex(Self.readFiles(in: folder))

        var context = FSEventStreamContext(version: 0, info: Unmanaged.passUnretained(self).toOpaque(), retain: nil, release: nil, copyDescription: nil)
        let callback: FSEventStreamCallback = { _, info, _, _, _, _ in
            guard let info else { return }
            Unmanaged<FileWatcher>.fromOpaque(info).takeUnretainedValue().check()
        }
        stream = FSEventStreamCreate(
            nil, callback, &context, [folder.path] as CFArray,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow), 0.1,
            FSEventStreamCreateFlags(kFSEventStreamCreateFlagFileEvents | kFSEventStreamCreateFlagNoDefer)
        )
        if let stream {
            FSEventStreamSetDispatchQueue(stream, queue)
            FSEventStreamStart(stream)
        }
    }

    deinit {
        guard let stream else { return }
        FSEventStreamStop(stream)
        FSEventStreamInvalidate(stream)
        FSEventStreamRelease(stream)
    }

    /// Call before Mel writes `text` to the file, so the write isn't reported as external.
    public func noteWritten(_ text: String, for kind: DocKind) {
        known.withLock { $0[kind] = text }
    }

    /// Reload when the editor has nothing unsaved; otherwise the user picks a version.
    public static func resolve(fileText: String, editorText: String, savedText: String) -> Resolution {
        editorText == savedText ? .reload(fileText) : .conflict(fileText: fileText)
    }

    private func check() {
        let current = Self.readFiles(in: folder)
        let changed = known.withLock { known in
            let changed = current.filter { known[$0.key] != $0.value }
            known.merge(changed) { $1 }
            return changed
        }
        for kind in DocKind.allCases {
            if let text = changed[kind] { onChange(kind, text) }
        }
    }

    private static func readFiles(in folder: URL) -> [DocKind: String] {
        var files: [DocKind: String] = [:]
        for kind in DocKind.allCases {
            files[kind] = try? String(contentsOf: folder.appending(path: kind.fileName), encoding: .utf8)
        }
        return files
    }
}
