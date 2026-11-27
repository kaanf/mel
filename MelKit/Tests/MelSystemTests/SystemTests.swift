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

struct NotifierTests {
    @Test func futureDateSchedulesPastOrNilShowsNow() throws {
        let reset = Date.now.addingTimeInterval(3600)
        let trigger = try #require(Notifier.trigger(at: reset))
        let next = try #require(trigger.nextTriggerDate())
        #expect(abs(next.timeIntervalSince(reset)) < 1)
        #expect(!trigger.repeats)
        #expect(Notifier.trigger(at: .now.addingTimeInterval(-1)) == nil)
        #expect(Notifier.trigger(at: nil) == nil)
    }

    @Test func outsideAnAppBundleIsANoOp() async {
        await Notifier.requestAuthorization()
        Notifier.post(title: "Requirements is ready", body: "Review it in Mel.")
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

    @Test func specCommitSkipsMelStateAndRepeatsQuietly() throws {
        defer { cleanUp() }
        try Git.initRepository(folder)
        try Git.run(["config", "user.name", "Mel Tests"], in: folder)
        try Git.run(["config", "user.email", "tests@example.com"], in: folder)
        let state = folder.appendingPathComponent("specs/timer/.mel")
        try FileManager.default.createDirectory(at: state, withIntermediateDirectories: true)
        try "{}".write(to: state.appendingPathComponent("state.json"), atomically: true, encoding: .utf8)
        try "# Tasks\n".write(to: folder.appendingPathComponent("specs/timer/TASKS.md"), atomically: true, encoding: .utf8)

        try Git.commit(paths: Git.specPaths(slug: "timer", project: folder), message: "Add spec", in: folder)
        try Git.commit(paths: Git.specPaths(slug: "timer", project: folder), message: "Again", in: folder)

        #expect(try Git.run(["log", "--format=%s"], in: folder) == "Add spec\n")
        #expect(try Git.run(["ls-files"], in: folder) == "specs/timer/TASKS.md\n")
    }

    func write(_ text: String, _ path: String) throws {
        let url = folder.appending(path: path)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try text.write(to: url, atomically: true, encoding: .utf8)
    }

    @Test func aTaskIsFoundByItsTrailerAfterTheCopy() throws {
        defer { cleanUp() }
        #expect(Git.head(at: folder) == nil)
        try Git.initRepository(folder)
        try Git.run(["config", "user.name", "Mel Tests"], in: folder)
        try Git.run(["config", "user.email", "tests@example.com"], in: folder)
        try write("a\n", "a.txt")
        try Git.commit(paths: ["."], message: "feat: old\n\nMel-Task: yoga/3", in: folder)
        let base = try #require(Git.head(at: folder))

        #expect(Git.hasCommit(with: "Mel-Task: yoga/3", since: base, in: folder) == false)   // before the copy
        try write("b\n", "a.txt")
        try Git.commit(paths: ["."], message: "feat(booking): local store\n\nMel-Task: yoga/30", in: folder)
        #expect(Git.hasCommit(with: "Mel-Task: yoga/3", since: base, in: folder) == false)
        try write("c\n", "a.txt")
        try Git.commit(paths: ["."], message: "feat(payments): checkout\n\nMel-Task: yoga/3", in: folder)
        #expect(Git.hasCommit(with: "Mel-Task: yoga/3", since: base, in: folder) == true)
        #expect(Git.hasCommit(with: "Mel-Task: yoga/3", since: "0000000", in: folder) == nil)
    }

    @Test func v2SpecCommitTakesOneSpecAndProjectContext() throws {
        defer { cleanUp() }
        try Git.initRepository(folder)
        try Git.run(["config", "user.name", "Mel Tests"], in: folder)
        try Git.run(["config", "user.email", "tests@example.com"], in: folder)
        try write("# Requirements\n", "specs/breaks/REQUIREMENTS.md")
        try write("{}", "specs/breaks/.mel/state.json")
        try write("# Spec\n", "specs/other/SPEC.md")

        // No .mel/project yet (A3 skipped): the commit still works.
        try Git.commit(paths: Git.specPaths(slug: "breaks", project: folder), message: "Add spec", in: folder)
        #expect(try Git.run(["ls-files"], in: folder) == "specs/breaks/REQUIREMENTS.md\n")

        try write("# Tech\n", ".mel/project/tech.md")
        #expect(Git.specPaths(slug: "breaks", project: folder).last == ".mel/project")
        try Git.commit(paths: Git.specPaths(slug: "breaks", project: folder), message: "Context", in: folder)
        #expect(try Git.run(["ls-files"], in: folder) == ".mel/project/tech.md\nspecs/breaks/REQUIREMENTS.md\n")
    }

    @Test func repositoriesOneLevelDeep() throws {
        defer { cleanUp() }
        try FileManager.default.createDirectory(at: folder.appending(path: "b-app/.git"), withIntermediateDirectories: true)
        try write("gitdir: /elsewhere\n", "a-worktree/.git")
        try FileManager.default.createDirectory(at: folder.appending(path: "notes"), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: folder.appending(path: "group/nested/.git"), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: folder.appending(path: ".hidden/.git"), withIntermediateDirectories: true)
        try write("", "file.txt")

        #expect(Git.repositories(in: folder).map(\.url.lastPathComponent) == ["a-worktree", "b-app"])
        #expect(Git.repositories(in: folder.appending(path: "missing")).isEmpty)
    }

    @Test func repositoryLanguageAndModified() throws {
        defer { cleanUp() }
        try write("ref: refs/heads/main\n", "web/.git/HEAD")
        try write("{}", "web/package.json")
        try write("{}", "web/tsconfig.json")
        try write("", "web/src/main.swift")          // below the root: ignored
        let head = folder.appending(path: "web/.git/HEAD")
        let then = Date(timeIntervalSince1970: 1_790_000_000)
        try FileManager.default.setAttributes([.modificationDate: then], ofItemAtPath: head.path)
        try FileManager.default.createDirectory(at: folder.appending(path: "plain/.git"), withIntermediateDirectories: true)
        try write("", "plain/notes.md")

        let repos = Git.repositories(in: folder)
        #expect(repos.map(\.language) == [nil, "TypeScript"])
        #expect(repos.map(\.modified) == [nil, then])

        try write("", "web/.git/index")             // index wins over HEAD
        #expect(try #require(Git.repositories(in: folder).last?.modified) > then)
    }

    @Test func branchAndFileCount() throws {
        defer { cleanUp() }
        #expect(Git.branch(at: folder) == nil)
        #expect(Git.fileCount(at: folder) == nil)
        try Git.run(["init", "--quiet", "--initial-branch", "feature/a3"], in: folder)
        #expect(Git.branch(at: folder) == "feature/a3")
        #expect(Git.fileCount(at: folder) == 0)

        try write("a", "one.txt")
        try write("b", "dir/two words.txt")
        try write("c", "untracked.txt")
        try Git.run(["add", "one.txt", "dir"], in: folder)
        #expect(Git.fileCount(at: folder) == 2)

        try Git.run(["config", "user.name", "Mel Tests"], in: folder)
        try Git.run(["config", "user.email", "tests@example.com"], in: folder)
        try Git.run(["commit", "--quiet", "-m", "x"], in: folder)
        try Git.run(["checkout", "--quiet", "--detach"], in: folder)
        #expect(Git.branch(at: folder) == nil)

        // A worktree's .git is a file pointing at its git dir.
        let worktree = folder.appending(path: "wt")
        try Git.run(["worktree", "add", "--quiet", "-b", "side", worktree.path], in: folder)
        #expect(Git.branch(at: worktree) == "side")
        #expect(Git.repositories(in: folder).first { $0.url.lastPathComponent == "wt" }?.modified != nil)
    }

    @Test(arguments: [
        (["Mel.xcodeproj", "README.md"], "Swift"), (["Package.swift"], "Swift"), (["build.gradle.kts"], "Kotlin"),
        (["package.json"], "JavaScript"), (["Cargo.toml"], "Rust"), (["go.mod"], "Go"),
        (["requirements.txt"], "Python"), (["pyproject.toml"], "Python"), (["Gemfile"], "Ruby"), (["README.md"], nil),
    ] as [([String], String?)])
    func languageFromRootFiles(_ files: [String], _ language: String?) {
        #expect(Git.language(rootFiles: Set(files)) == language)
    }

    @Test func failureCarriesGitOutput() throws {
        defer { cleanUp() }
        #expect(throws: Git.Failure.self) { try Git.commit(paths: ["specs"], message: "x", in: folder) }
    }
}
