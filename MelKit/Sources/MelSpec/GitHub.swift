import Foundation

// GitHub through the user's GitHub CLI (OQ #44, GH-1 to GH-5): what Mel reads from `gh`'s JSON and
// keeps in a spec. The calls themselves are in MelSystem.

/// A repo from `gh repo list --json nameWithOwner,isPrivate,isEmpty,primaryLanguage,updatedAt,url`.
public struct GitHubRepo: Codable, Identifiable, Hashable, Sendable {
    public var nameWithOwner: String
    public var isPrivate: Bool
    public var isEmpty: Bool
    public var language: String?
    public var updatedAt: Date?
    public var url: URL

    public var id: String { nameWithOwner }
    public var name: String { nameWithOwner.split(separator: "/").last.map(String.init) ?? nameWithOwner }

    public init(nameWithOwner: String, isPrivate: Bool, isEmpty: Bool, language: String? = nil, updatedAt: Date? = nil, url: URL) {
        self.nameWithOwner = nameWithOwner
        self.isPrivate = isPrivate
        self.isEmpty = isEmpty
        self.language = language
        self.updatedAt = updatedAt
        self.url = url
    }

    private struct Row: Decodable {
        struct Language: Decodable { var name: String }
        var nameWithOwner: String
        var isPrivate: Bool
        var isEmpty: Bool
        var primaryLanguage: Language?
        var updatedAt: Date?
        var url: URL
    }

    /// `gh repo list`'s JSON, newest first.
    public static func list(json: Data) throws -> [GitHubRepo] {
        try decoder.decode([Row].self, from: json)
            .map { GitHubRepo(nameWithOwner: $0.nameWithOwner, isPrivate: $0.isPrivate, isEmpty: $0.isEmpty, language: $0.primaryLanguage?.name, updatedAt: $0.updatedAt, url: $0.url) }
            .sorted { ($0.updatedAt ?? .distantPast) > ($1.updatedAt ?? .distantPast) }
    }
}

/// `owner/name` from a remote's URL: `https://github.com/o/n(.git)` or `git@github.com:o/n(.git)`. Nil for other hosts.
public func gitHubName(remote: String) -> String? {
    let url = remote.trimmingCharacters(in: .whitespacesAndNewlines)
    let path: Substring
    if let range = url.range(of: "github.com/") ?? url.range(of: "github.com:") {
        path = url[range.upperBound...]
    } else {
        return nil
    }
    let parts = path.split(separator: "/")
    guard parts.count == 2 else { return nil }
    let name = parts[1].hasSuffix(".git") ? parts[1].dropLast(4) : parts[1]
    return "\(parts[0])/\(name)"
}

/// The one-time code `gh auth login --web` prints: "! First copy your one-time code: 8A50-1EF3".
public func gitHubDeviceCode(in output: String) -> String? {
    guard let range = output.range(of: "one-time code: ") else { return nil }
    let code = output[range.upperBound...].prefix { !$0.isWhitespace }
    return code.isEmpty ? nil : String(code)
}

/// The spec's pull request (GH-4): opened when its last task is done, merged from Mel.
public struct PullRequest: Codable, Hashable, Sendable {
    public var number: Int
    public var url: URL
    /// Merged on GitHub; nothing else changes after.
    public var merged = false
    /// "Merge when checks pass": GitHub merges it by itself once its checks pass.
    public var autoMerge = false

    public init(number: Int, url: URL, merged: Bool = false, autoMerge: Bool = false) {
        self.number = number
        self.url = url
        self.merged = merged
        self.autoMerge = autoMerge
    }

    /// From the URL `gh pr create` prints: `https://github.com/o/n/pull/14`.
    public init?(created output: String) {
        guard let line = output.split(whereSeparator: \.isNewline).last(where: { $0.contains("/pull/") }),
              let url = URL(string: String(line).trimmingCharacters(in: .whitespaces)),
              let number = Int(url.lastPathComponent) else { return nil }
        self.init(number: number, url: url)
    }

    /// What the pull request says: what works now and what was decided, from the tasks' reports.
    public static func body(slug: String, reports: [BuildReport]) -> String {
        var lines = ["Built by Mel from `specs/\(slug)`, one commit per task, each checked before it was pushed."]
        let works = reports.flatMap(\.works)
        if !works.isEmpty { lines += ["", "## What works now"] + works.map { "- \($0)" } }
        let decisions = reports.flatMap(\.decisions)
        if !decisions.isEmpty { lines += ["", "## Decided while building"] + decisions.map { "- **\($0.title)**: \($0.why)" } }
        let notDone = reports.flatMap(\.notDone)
        if !notDone.isEmpty { lines += ["", "## Not done"] + notDone.map { "- \($0)" } }
        return lines.joined(separator: "\n")
    }
}

/// `gh pr view N --json state,statusCheckRollup`: the pull request now, read when Build shows it. Not stored.
public struct PullRequestStatus: Hashable, Sendable {
    public enum State: String, Sendable { case open = "OPEN", merged = "MERGED", closed = "CLOSED" }

    public struct Check: Hashable, Sendable {
        public enum Outcome: Sendable { case pending, passed, failed }
        public var name: String
        public var outcome: Outcome

        public init(name: String, outcome: Outcome) {
            self.name = name
            self.outcome = outcome
        }
    }

    public var state: State
    public var checks: [Check]

    public init(state: State, checks: [Check]) {
        self.state = state
        self.checks = checks
    }

    public var failed: [Check] { checks.filter { $0.outcome == .failed } }
    public var pending: [Check] { checks.filter { $0.outcome == .pending } }

    private struct Row: Decodable {
        struct Item: Decodable {
            // A CheckRun has name / status / conclusion; a StatusContext has context / state.
            var name: String?
            var context: String?
            var status: String?
            var conclusion: String?
            var state: String?
        }
        var state: String
        var statusCheckRollup: [Item]?
    }

    public static func parse(json: Data) throws -> PullRequestStatus {
        let row = try JSONDecoder().decode(Row.self, from: json)
        let checks = (row.statusCheckRollup ?? []).map { item in
            let result = (item.conclusion ?? item.state ?? "").uppercased()
            let outcome: Check.Outcome = switch result {
            case "SUCCESS", "NEUTRAL", "SKIPPED": .passed
            case "FAILURE", "ERROR", "CANCELLED", "TIMED_OUT", "ACTION_REQUIRED", "STARTUP_FAILURE": .failed
            default: .pending
            }
            return Check(name: item.name ?? item.context ?? "check", outcome: outcome)
        }
        return PullRequestStatus(state: State(rawValue: row.state) ?? .open, checks: checks)
    }
}

private let decoder: JSONDecoder = {
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    return decoder
}()
