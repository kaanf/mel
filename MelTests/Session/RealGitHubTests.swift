import Foundation
import Testing
import MelAgent
import MelSpec
import MelSystem
@testable import Mel

/// GH-1 to GH-5 against real GitHub with the user's `gh`: Mel's calls, in the order a spec makes them.
/// Makes a private repo `mel-gh-test-<time>` with one Actions check, pushes, opens a pull request,
/// waits for the check, merges, and deletes the repo. Opt-in, since it writes to the account:
/// `TEST_RUNNER_MEL_REAL_GITHUB=1 xcodebuild test -only-testing:MelTests/RealGitHubTests`.
@MainActor
@Suite(.enabled(if: ProcessInfo.processInfo.environment["MEL_REAL_GITHUB"] == "1"))
struct RealGitHubTests {
    @Test func repoToMergedPullRequest() async throws {
        let name = "mel-gh-test-\(Int(Date.now.timeIntervalSince1970))"
        let folder = FileManager.default.temporaryDirectory.appending(path: name, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: folder.appending(path: ".github/workflows"), withIntermediateDirectories: true)
        try "# \(name)\n\nMade by Mel's tests; deleted when they end.\n".write(to: folder.appending(path: "README.md"), atomically: true, encoding: .utf8)
        try """
            name: check
            on: pull_request
            jobs:
              test:
                runs-on: ubuntu-latest
                steps:
                  - run: echo ok

            """.write(to: folder.appending(path: ".github/workflows/check.yml"), atomically: true, encoding: .utf8)
        for arguments in [["init", "--quiet", "-b", "main"], ["add", "-A"], ["commit", "--quiet", "-m", "Start"]] { try git(folder, arguments) }

        let app = AppState(adapter: ClaudeCode(), makeRunner: { AgentRunner(adapter: ClaudeCode(), executable: $0) },
                           defaults: UserDefaults(suiteName: "mel-real-github-\(UUID().uuidString)")!)
        await app.scanGitHub()
        let login = try #require(app.github.login, "gh isn't signed in")
        let cli = try #require(app.gitHubCLI)
        #expect(!app.githubRepos.isEmpty)
        let project = try app.addProject(folder)
        #expect(app.remotes[project.id] == nil)

        // GH-2 / GH-3: a new private repo; main is pushed with it.
        try await app.createRepo(for: project, name: name, isPrivate: true)
        defer { _ = try? Process.run(cli.executable, arguments: ["repo", "delete", "\(login)/\(name)", "--yes"]).waitUntilExit() }
        #expect(app.remotes[project.id] == "\(login)/\(name)")
        #expect(Git.origin(at: folder).flatMap(gitHubName(remote:)) == "\(login)/\(name)")
        await app.loadGitHubRepos()
        #expect(app.githubRepos.first?.nameWithOwner == "\(login)/\(name)")
        #expect(app.githubRepos.first?.isPrivate == true)

        // GH-4: the spec branch with a task's commit, pushed; the pull request; its check.
        try git(folder, ["checkout", "--quiet", "-b", "mel/real-test"])
        try "done\n".write(to: folder.appending(path: "task-1.txt"), atomically: true, encoding: .utf8)
        try git(folder, ["add", "-A"])
        try git(folder, ["commit", "--quiet", "-m", "feat: task 1\n\nMel-Task: real-test/1"])
        try await Task.detached { try cli.push(branch: "mel/real-test", in: folder) }.value
        let report = BuildReport(works: ["task-1.txt says done."], decisions: [.init(title: "A text file", why: "Smallest change.", instead: "Nothing")])
        let output = try await Task.detached { try cli.createPullRequest(branch: "mel/real-test", title: "Real test", body: PullRequest.body(slug: "real-test", reports: [report]), in: folder) }.value
        let pull = try #require(PullRequest(created: output), "gh pr create printed: \(output)")
        #expect(pull.url.absoluteString.hasPrefix("https://github.com/\(login)/\(name)/pull/"))

        var status = PullRequestStatus(state: .open, checks: [])
        for _ in 0..<40 {
            let json = try await Task.detached { try cli.pullRequest(pull.number, in: folder) }.value
            status = try PullRequestStatus.parse(json: json)
            if !status.checks.isEmpty, status.pending.isEmpty { break }
            try await Task.sleep(for: .seconds(6))
        }
        #expect(status.state == .open)
        // The account's own GitHub Apps add checks too (Devin Review here); ours is "test".
        #expect(status.checks.first { $0.name == "test" }?.outcome == .passed)
        #expect(status.failed.isEmpty)

        // GH-5: squashed, the branch deleted, this Mac on an up-to-date main.
        try await Task.detached { try cli.merge(pull.number, auto: false, in: folder) }.value
        let merged = try PullRequestStatus.parse(json: try await Task.detached { try cli.pullRequest(pull.number, in: folder) }.value)
        #expect(merged.state == .merged)
        #expect(Git.branch(at: folder) == "main")
        #expect(FileManager.default.fileExists(atPath: folder.appending(path: "task-1.txt").path))
    }

    private func git(_ repo: URL, _ arguments: [String]) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = arguments
        process.currentDirectoryURL = repo
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try process.run()
        process.waitUntilExit()
        if process.terminationStatus != 0 { throw CocoaError(.fileWriteUnknown) }
    }
}
