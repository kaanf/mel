import AppKit

public enum SystemActions {
    /// Opens the user's terminal app (Terminal by default) in `directory` and runs `command`.
    /// Uses a temporary `.command` file that deletes itself, so no AppleScript or Automation permission.
    public static func openInTerminal(command: String, in directory: URL) throws {
        let file = try commandFile(command: command, in: directory)
        guard NSWorkspace.shared.open(file) else {
            try? FileManager.default.removeItem(at: file)
            throw CocoaError(.fileReadUnknown, userInfo: [NSFilePathErrorKey: file.path])
        }
    }

    static func commandFile(command: String, in directory: URL) throws -> URL {
        let file = FileManager.default.temporaryDirectory.appendingPathComponent("mel-\(UUID().uuidString).command")
        let script = """
            #!/bin/sh
            rm -f -- "$0"
            cd -- \(shellQuoted(directory.path)) || exit 1
            \(command)

            """
        try script.write(to: file, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: file.path)
        return file
    }

    static func shellQuoted(_ s: String) -> String {
        "'" + s.replacingOccurrences(of: "'", with: #"'\''"#) + "'"
    }

    /// The board's "Open in Editor": in `app` (Settings › Specs › Open files in), or the app macOS uses for the file.
    public static func open(_ url: URL, with app: URL? = nil) {
        guard let app else { NSWorkspace.shared.open(url); return }
        NSWorkspace.shared.open([url], withApplicationAt: app, configuration: NSWorkspace.OpenConfiguration())
    }

    /// The apps on this Mac that open Markdown, by name.
    public static func markdownEditors() -> [URL] {
        let sample = FileManager.default.temporaryDirectory.appending(path: "mel.md")
        if !FileManager.default.fileExists(atPath: sample.path) { try? Data().write(to: sample) }
        return NSWorkspace.shared.urlsForApplications(toOpen: sample)
            .sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
    }

    public static func showInFinder(_ url: URL) {
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    public static func copy(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    /// macOS dictation (Edit › Start Dictation) into the focused text field.
    @MainActor
    public static func startDictation() {
        NSApp.sendAction(Selector(("startDictation:")), to: nil, from: nil)
    }
}
