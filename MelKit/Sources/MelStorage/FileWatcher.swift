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

    private let core: Core
    private let queue = DispatchQueue(label: "mel.filewatcher")
    nonisolated(unsafe) private var stream: FSEventStreamRef?

    public init(folder: URL, onChange: @escaping @Sendable (DocKind, String) -> Void) {
        core = Core(folder: folder, onChange: onChange)
        // The stream holds `core`, not `self`: a callback in flight must never retain a watcher
        // that is being deinitialized.
        var context = FSEventStreamContext(version: 0, info: Unmanaged.passRetained(core).toOpaque(), retain: nil, release: nil, copyDescription: nil)
        let callback: FSEventStreamCallback = { _, info, _, _, _, _ in
            guard let info else { return }
            Unmanaged<Core>.fromOpaque(info).takeUnretainedValue().check()
        }
        stream = FSEventStreamCreate(
            nil, callback, &context, [folder.path] as CFArray,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow), 0.1,
            FSEventStreamCreateFlags(kFSEventStreamCreateFlagFileEvents | kFSEventStreamCreateFlagNoDefer)
        )
        if let stream {
            FSEventStreamSetDispatchQueue(stream, queue)
            FSEventStreamStart(stream)
        } else {
            Unmanaged.passUnretained(core).release()
        }
    }

    deinit {
        guard let stream else { return }
        FSEventStreamStop(stream)
        FSEventStreamInvalidate(stream)
        queue.sync {}   // let a callback already running finish before the stream's `core` goes
        FSEventStreamRelease(stream)
        Unmanaged.passUnretained(core).release()
    }

    /// Call before Mel writes `text` to the file, so the write isn't reported as external.
    public func noteWritten(_ text: String, for kind: DocKind) {
        core.state.withLock { state in
            // Text equal to the file causes no change to clear it; pending, it would swallow a later edit back to it.
            guard state.known[kind] != text else { return }
            state.ownWrites[kind, default: []].append(text)
        }
    }

    /// Reload when the editor has nothing unsaved; otherwise the user picks a version.
    public static func resolve(fileText: String, editorText: String, savedText: String) -> Resolution {
        editorText == savedText ? .reload(fileText) : .conflict(fileText: fileText)
    }

    func check() { core.check() }

    private final class Core: Sendable {
        /// `known`: file text as last seen on disk. `ownWrites`: texts Mel announced via `noteWritten`
        /// that haven't been seen on disk yet, oldest first.
        struct State {
            var known: [DocKind: String]
            var ownWrites: [DocKind: [String]] = [:]
        }

        let folder: URL
        let state: Mutex<State>
        let onChange: @Sendable (DocKind, String) -> Void

        init(folder: URL, onChange: @escaping @Sendable (DocKind, String) -> Void) {
            self.folder = folder
            self.onChange = onChange
            state = Mutex(State(known: FileWatcher.readFiles(in: folder)))
        }

        /// Re-reads the files and reports text that is neither what was last seen nor one of Mel's
        /// own pending writes. Reading inside the lock keeps concurrent checks consistent.
        func check() {
            let changed = state.withLock { state in
                var changed: [DocKind: String] = [:]
                for (kind, text) in FileWatcher.readFiles(in: folder) where state.known[kind] != text {
                    state.known[kind] = text
                    if let own = state.ownWrites[kind], let i = own.firstIndex(of: text) {
                        // Our write landed; it and any older write it replaced are done.
                        state.ownWrites[kind]!.removeFirst(i + 1)
                    } else {
                        changed[kind] = text
                    }
                }
                return changed
            }
            for kind in DocKind.allCases {
                if let text = changed[kind] { onChange(kind, text) }
            }
        }
    }

    fileprivate static func readFiles(in folder: URL) -> [DocKind: String] {
        var files: [DocKind: String] = [:]
        for kind in DocKind.allCases {
            files[kind] = try? String(contentsOf: folder.appending(path: kind.fileName), encoding: .utf8)
        }
        return files
    }
}
