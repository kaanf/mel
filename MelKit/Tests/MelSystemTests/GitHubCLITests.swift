import Foundation
import Testing
@testable import MelSystem

/// `GitHubCLI` against a fake `gh` that logs its arguments, and real git pushing to a bare repo.
struct GitHubCLITests {
    let folder = FileManager.default.temporaryDirectory.appending(path: "mel-gh-\(UUID().uuidString)", directoryHint: .isDirectory)

    /// A `gh` that appends its arguments to `gh.log` and prints `output`.
    private func fakeGitHub(output: String = "") throws -> GitHubCLI {
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let script = folder.appending(path: "gh")
        try "#!/bin/sh\necho \"$@\" >> \"$(dirname \"$0\")/gh.log\"\nprintf '%s' '\(output)'\n".write(to: script, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: script.path)
        return GitHubCLI(executable: script)
    }

    private var log: [String] {
        ((try? String(contentsOf: folder.appending(path: "gh.log"), encoding: .utf8)) ?? "").split(separator: "\n").map(String.init)
    }

    private func git(_ arguments: [String], in repo: URL) throws {
        try Git.run(["-c", "user.name=Mel Tests", "-c", "user.email=tests@example.com"] + arguments, in: repo)
    }

    @Test func pushSendsTheBranchToOriginsPushURL() throws {
        let cli = try fakeGitHub()
        let (repo, remote) = (folder.appending(path: "repo"), folder.appending(path: "remote.git"))
        try FileManager.default.createDirectory(at: repo, withIntermediateDirectories: true)
        try Git.run(["init", "--quiet", "--bare", remote.path], in: folder)
        try git(["init", "--quiet", "-b", "main"], in: repo)
        try git(["commit", "--quiet", "--allow-empty", "-m", "Start"], in: repo)
        try git(["checkout", "--quiet", "-b", "mel/waitlist"], in: repo)
        // origin reads as GitHub; pushes go to the bare repo.
        try git(["remote", "add", "origin", "https://github.com/kaanf/waitlist.git"], in: repo)
        try git(["remote", "set-url", "--push", "origin", remote.path], in: repo)
        #expect(Git.origin(at: repo) == "https://github.com/kaanf/waitlist.git")
        #expect(Git.hasBranch("mel/waitlist", in: repo))
        #expect(!Git.hasBranch("mel/other", in: repo))

        try cli.push(branch: "mel/waitlist", in: repo)
        #expect(try Git.run(["branch", "--list", "mel/waitlist"], in: remote).contains("mel/waitlist"))
    }

    @Test func originIsNilWithoutOne() throws {
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try Git.run(["init", "--quiet"], in: folder)
        #expect(Git.origin(at: folder) == nil)
    }

    @Test func pullRequestCallsNameTheBranchAndNumber() throws {
        let cli = try fakeGitHub(output: "https://github.com/kaanf/waitlist/pull/7")
        #expect(try cli.createPullRequest(branch: "mel/waitlist", title: "Waitlist", body: "Built by Mel", in: folder) == "https://github.com/kaanf/waitlist/pull/7")
        try cli.merge(7, auto: true, in: folder)
        _ = try cli.pullRequest(7, in: folder)
        #expect(log == [
            "pr create --head mel/waitlist --title Waitlist --body Built by Mel",
            "pr merge 7 --squash --delete-branch --auto",
            "pr view 7 --json state,statusCheckRollup",
        ])
    }

    @Test func createMakesTheFolderARepoAndPushesOnlyWithACommit() throws {
        let cli = try fakeGitHub(output: "✓ Created repository kaanf/yoga on GitHub\n  https://github.com/kaanf/yoga\n")
        let repo = folder.appending(path: "yoga")
        try FileManager.default.createDirectory(at: repo, withIntermediateDirectories: true)
        #expect(try cli.create(name: "yoga", isPrivate: true, from: repo) == "kaanf/yoga")
        #expect(Git.isRepository(repo))
        try git(["commit", "--quiet", "--allow-empty", "-m", "Start"], in: repo)
        try cli.create(name: "yoga", isPrivate: false, from: repo)
        #expect(log == [
            "repo create yoga --private --source \(repo.path(percentEncoded: false)) --remote origin",
            "repo create yoga --public --source \(repo.path(percentEncoded: false)) --remote origin --push",
        ])
    }

    @Test func aFailedCallThrowsWhatItPrinted() throws {
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let script = folder.appending(path: "gh")
        try "#!/bin/sh\necho 'GraphQL: Pull request is not mergeable' >&2\nexit 1\n".write(to: script, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: script.path)
        #expect(throws: Git.Failure.self) { try GitHubCLI(executable: script).merge(7, auto: false, in: folder) }
        do { try GitHubCLI(executable: script).merge(7, auto: false, in: folder) } catch { #expect(error.localizedDescription == "GraphQL: Pull request is not mergeable") }
    }
}
