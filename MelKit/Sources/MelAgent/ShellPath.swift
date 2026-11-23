import Foundation

/// Resolves executables the way the user's terminal would. A Dock-launched app only gets
/// `/usr/bin:/bin:/usr/sbin:/sbin`, so the login shell is asked for its `PATH`.
public enum ShellPath {
    /// `PATH` from `$SHELL -l -i -c 'printf %s "$PATH"'`, or "" on failure or after 5 s.
    /// Interactive so `.zshrc` additions count; takes the last line because shell scripts may print.
    public static func loginPATH() async -> String {
        await loginPATH(shell: ProcessInfo.processInfo.environment["SHELL"] ?? "/bin/zsh")
    }

    static func loginPATH(shell: String) async -> String {
        guard let output = await Subprocess.run(URL(fileURLWithPath: shell), ["-l", "-i", "-c", #"printf %s "$PATH""#]),
              output.status == 0 else { return "" }
        let last = output.stdout.split(whereSeparator: \.isNewline).last ?? ""
        return last.trimmingCharacters(in: .whitespaces)
    }

    /// First executable named `name` in the login `PATH`, then `extraPaths`.
    public static func find(_ name: String, extraPaths: [String]) async -> URL? {
        find(name, in: await loginPATH().split(separator: ":").map(String.init) + extraPaths)
    }

    static func find(_ name: String, in directories: [String]) -> URL? {
        var seen = Set<String>()
        for dir in directories where !dir.isEmpty && seen.insert(dir).inserted {
            let path = (NSString(string: dir).expandingTildeInPath as NSString).appendingPathComponent(name)
            var isDirectory: ObjCBool = false
            if FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory), !isDirectory.boolValue,
               FileManager.default.isExecutableFile(atPath: path) {
                return URL(fileURLWithPath: path)
            }
        }
        return nil
    }
}
