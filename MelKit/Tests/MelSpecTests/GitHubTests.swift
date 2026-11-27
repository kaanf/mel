import Foundation
import Testing
@testable import MelSpec

/// `gh` 2.96.0's output shapes, recorded on this Mac 2026-11-28 (names changed).
struct GitHubTests {
    @Test func repoListIsNewestFirstWithItsLanguage() throws {
        let json = """
            [{"isEmpty":false,"isPrivate":false,"nameWithOwner":"kaanf/mel","primaryLanguage":{"name":"Swift"},"updatedAt":"2026-11-23T13:50:59Z","url":"https://github.com/kaanf/mel"},\
            {"isEmpty":true,"isPrivate":true,"nameWithOwner":"kaanf/yoga-app","primaryLanguage":null,"updatedAt":"2026-11-27T14:57:36Z","url":"https://github.com/kaanf/yoga-app"}]
            """
        let repos = try GitHubRepo.list(json: Data(json.utf8))
        #expect(repos.map(\.nameWithOwner) == ["kaanf/yoga-app", "kaanf/mel"])
        #expect(repos[0].isEmpty && repos[0].isPrivate && repos[0].language == nil && repos[0].name == "yoga-app")
        #expect(repos[1].language == "Swift")
    }

    @Test func remoteNamesFromHTTPSAndSSH() {
        #expect(gitHubName(remote: "https://github.com/kaanf/mel.git") == "kaanf/mel")
        #expect(gitHubName(remote: "https://github.com/kaanf/mel\n") == "kaanf/mel")
        #expect(gitHubName(remote: "git@github.com:kaanf/mel.git") == "kaanf/mel")
        #expect(gitHubName(remote: "https://gitlab.com/kaanf/mel.git") == nil)
        #expect(gitHubName(remote: "/tmp/remote.git") == nil)
    }

    /// `gh auth login --web` with no terminal: the code, then the URL, on stderr.
    @Test func deviceCodeFromLogin() {
        let output = "\n! First copy your one-time code: 8A50-1EF3\nOpen this URL to continue in your web browser: https://github.com/login/device\n"
        #expect(gitHubDeviceCode(in: output) == "8A50-1EF3")
        #expect(gitHubDeviceCode(in: "\n! First copy your one-time") == nil)
    }

    @Test func pullRequestFromCreateOutput() throws {
        let pull = try #require(PullRequest(created: "\nCreating pull request for mel/waitlist into main in kaanf/yoga\n\nhttps://github.com/kaanf/yoga/pull/14\n"))
        #expect(pull.number == 14 && pull.url.absoluteString == "https://github.com/kaanf/yoga/pull/14" && !pull.merged)
        #expect(PullRequest(created: "nothing") == nil)
    }

    /// Check runs (Actions) and status contexts (other CI) in one rollup.
    @Test func pullRequestStatusReadsBothKindsOfCheck() throws {
        let json = """
            {"state":"OPEN","statusCheckRollup":[\
            {"__typename":"CheckRun","name":"build","status":"COMPLETED","conclusion":"SUCCESS"},\
            {"__typename":"CheckRun","name":"test","status":"IN_PROGRESS","conclusion":""},\
            {"__typename":"StatusContext","context":"ci/circleci","state":"FAILURE"}]}
            """
        let status = try PullRequestStatus.parse(json: Data(json.utf8))
        #expect(status.state == .open)
        #expect(status.checks.map(\.name) == ["build", "test", "ci/circleci"])
        #expect(status.pending.map(\.name) == ["test"])
        #expect(status.failed.map(\.name) == ["ci/circleci"])
        #expect(try PullRequestStatus.parse(json: Data(#"{"state":"MERGED","statusCheckRollup":[]}"#.utf8)).state == .merged)
    }

    @Test func pullRequestBodyFromReports() {
        let report = BuildReport(works: ["Members can join the waitlist."], decisions: [.init(title: "Kept on the phone", why: "No server yet.", instead: "A server table")], notDone: [], refused: [])
        let body = PullRequest.body(slug: "waitlist", reports: [report])
        #expect(body.contains("`specs/waitlist`"))
        #expect(body.contains("## What works now\n- Members can join the waitlist."))
        #expect(body.contains("## Decided while building\n- **Kept on the phone**: No server yet."))
        #expect(!body.contains("## Not done"))
    }

    @Test func oldStateWithoutGitHubFieldsDecodes() throws {
        let run = try JSONDecoder().decode(TaskRun.self, from: Data(#"{"state":"done","byHand":false}"#.utf8))
        #expect(run.pushed == nil)
    }
}
