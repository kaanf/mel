import Foundation
import Testing
@testable import MelSystem

struct SystemActionsTests {
    @Test func commandFileRunsInDirectoryAndRemovesItself() throws {
        let folder = URL(fileURLWithPath: "/tmp/it's a folder")
        let file = try SystemActions.commandFile(command: "claude auth login", in: folder)
        defer { try? FileManager.default.removeItem(at: file) }

        let script = try String(contentsOf: file, encoding: .utf8)
        #expect(script == """
            #!/bin/sh
            rm -f -- "$0"
            cd -- '/tmp/it'\\''s a folder' || exit 1
            claude auth login

            """)
        #expect(file.pathExtension == "command")
        let permissions = try FileManager.default.attributesOfItem(atPath: file.path)[.posixPermissions] as? Int
        #expect(permissions == 0o700)
    }
}

@Suite(.enabled(if: Git.isAvailable))
struct GitTests {
    let folder: URL

    init() throws {
        folder = FileManager.default.temporaryDirectory.appendingPathComponent("mel-git-\(UUID())")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    }

    func cleanUp() { try? FileManager.default.removeItem(at: folder) }

    @Test func initAndCommitOnlyGivenPaths() throws {
        defer { cleanUp() }
        #expect(!Git.isRepository(folder))
        try Git.initRepository(folder)
        #expect(Git.isRepository(folder))
        try Git.run(["config", "user.name", "Mel Tests"], in: folder)
        try Git.run(["config", "user.email", "tests@example.com"], in: folder)

        let specs = folder.appendingPathComponent("specs")
        try FileManager.default.createDirectory(at: specs, withIntermediateDirectories: true)
        try "# Product\n".write(to: specs.appendingPathComponent("PRODUCT.md"), atomically: true, encoding: .utf8)
        try "scratch\n".write(to: folder.appendingPathComponent("notes.txt"), atomically: true, encoding: .utf8)

        try Git.commit(paths: ["specs"], message: "Add spec", in: folder)

        #expect(try Git.run(["log", "--format=%s"], in: folder) == "Add spec\n")
        #expect(try Git.run(["ls-files"], in: folder) == "specs/PRODUCT.md\n")
    }

    @Test func failureCarriesGitOutput() throws {
        defer { cleanUp() }
        #expect(throws: Git.Failure.self) { try Git.commit(paths: ["specs"], message: "x", in: folder) }
    }
}
