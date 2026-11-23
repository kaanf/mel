import Foundation
import Testing
@testable import MelAgent

struct ShellPathTests {
    @Test func findsInExtraPaths() async {
        #expect(await ShellPath.find("sh", extraPaths: ["/bin"])?.path == "/bin/sh")
    }

    @Test func missingExecutable() async {
        #expect(await ShellPath.find("mel-no-such-tool", extraPaths: ["/bin"]) == nil)
    }

    @Test func loginPATHFromShell() async {
        #expect(await ShellPath.loginPATH(shell: "/bin/zsh").split(separator: ":").contains("/usr/bin"))
    }

    @Test func skipsDirectoriesAndDuplicates() {
        // "/bin" is a directory, not an executable.
        #expect(ShellPath.find("bin", in: ["/", "/bin", "/bin"]) == nil)
        #expect(ShellPath.find("sh", in: ["", "/usr/bin", "/bin"])?.path == "/bin/sh")
    }

    /// A login script that hangs (and leaves a child holding stdout) must not block detection.
    @Test func hangingShellTimesOut() async throws {
        let shell = FileManager.default.temporaryDirectory.appendingPathComponent("mel-hang-\(UUID()).sh")
        try "#!/bin/sh\nsleep 30\n".write(to: shell, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: shell.path)
        defer { try? FileManager.default.removeItem(at: shell) }

        let start = ContinuousClock.now
        #expect(await ShellPath.loginPATH(shell: shell.path) == "")
        #expect(ContinuousClock.now - start < .seconds(8))
    }
}
