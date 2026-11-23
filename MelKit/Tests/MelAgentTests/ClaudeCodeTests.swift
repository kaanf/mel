import Foundation
import MelSpec
import Testing
@testable import MelAgent

func fixture(_ name: String) throws -> URL {
    try #require(Bundle.module.url(forResource: name, withExtension: nil, subdirectory: "Fixtures"))
}

func fixtureText(_ name: String) throws -> String {
    try String(contentsOf: fixture(name), encoding: .utf8)
}

struct ClaudeCodeTests {
    let claude = ClaudeCode()
    let folder = URL(fileURLWithPath: "/tmp/project")

    func events(_ name: String) throws -> [AgentEvent] {
        try fixtureText(name).split(separator: "\n").flatMap { claude.parse(line: $0) }
    }

    func text(_ events: [AgentEvent]) -> String {
        events.map { if case .text(let t) = $0 { t } else { "" } }.joined()
    }

    // MARK: Invocation

    @Test func freshRunIsReadOnlyAndNotPersisted() {
        let args = claude.arguments(for: AgentRequest(prompt: "x", workingDirectory: folder, persistSession: false))
        #expect(args.starts(with: ["-p", "--output-format", "stream-json", "--verbose"]))
        #expect(args.contains("--include-partial-messages"))
        #expect(args.contains("--restricted") && args.contains("--strict-mcp-config"))
        #expect(args[args.firstIndex(of: "--tools")! + 1] == "Read,Glob,Grep")
        #expect(args[args.firstIndex(of: "--permission-mode")! + 1] == "manual")
        #expect(args.contains("--no-session-persistence"))
        #expect(!args.contains("--resume"))
        #expect(!args.contains { $0.contains("Write") || $0.contains("Edit") || $0.contains("Bash") })
    }

    @Test func resumeKeepsSession() {
        let request = AgentRequest(prompt: "x", workingDirectory: folder, resumeSessionID: "abc", persistSession: true)
        let args = claude.arguments(for: request)
        #expect(args[args.firstIndex(of: "--resume")! + 1] == "abc")
        #expect(!args.contains("--no-session-persistence"))
        #expect(!args.contains("--append-system-prompt"))
    }

    @Test func systemPromptIsAppended() {
        let request = AgentRequest(prompt: "x", workingDirectory: folder, persistSession: false, systemPrompt: "Answer as JSON.")
        let args = claude.arguments(for: request)
        #expect(args[args.firstIndex(of: "--append-system-prompt")! + 1] == "Answer as JSON.")
    }

    @Test func environmentIsAnAllowlist() {
        let env = claude.environment(path: "/opt/homebrew/bin:/usr/bin")
        #expect(Set(env.keys) == ["HOME", "USER", "PATH", "TERM", "NO_COLOR"])
        #expect(env["PATH"] == "/opt/homebrew/bin:/usr/bin")
        #expect(env["TERM"] == "dumb" && env["NO_COLOR"] == "1")
        #expect(env["USER"]?.isEmpty == false)
    }

    @Test func loginCommandQuotesPath() {
        #expect(claude.loginCommand(executable: URL(fileURLWithPath: "/opt/homebrew/bin/claude"))
            == "'/opt/homebrew/bin/claude' auth login")
        #expect(claude.loginCommand(executable: URL(fileURLWithPath: "/Users/o'neil/bin/claude"))
            == #"'/Users/o'\''neil/bin/claude' auth login"#)
    }

    // MARK: Detection

    @Test func version() {
        #expect(ClaudeCode.version(from: "2.1.311 (Claude Code)\n") == "2.1.311")
        #expect(ClaudeCode.version(from: "") == nil)
    }

    @Test func authStatus() throws {
        #expect(ClaudeCode.isSignedIn(authStatus: try fixtureText("claude-2.1.311-auth-status-signed-in.json")) == true)
        #expect(ClaudeCode.isSignedIn(authStatus: try fixtureText("claude-2.1.311-auth-status-signed-out.json")) == false)
        #expect(ClaudeCode.isSignedIn(authStatus: #"{"loggedIn": true, "authMethod": "api_key"}"#) == false)
        #expect(ClaudeCode.isSignedIn(authStatus: "error: unknown command") == nil)
    }

    // MARK: Stream

    @Test func partialMessagesTextOnlyFromDeltas() throws {
        let events = try events("claude-2.1.311-partial-messages.jsonl")
        guard case .session(let id) = events.first else { Issue.record("no session first"); return }
        #expect(!id.isEmpty)
        #expect(text(events) == "HELLO THERE, HOW ARE YOU?")
        #expect(events.last == .done(result: "HELLO THERE, HOW ARE YOU?"))
        #expect(events.contains(.rateLimit(allowed: true, resetsAt: Date(timeIntervalSince1970: 1795448400))))
    }

    @Test func discoveryReadsThenAnswersJSON() throws {
        let events = try events("claude-2.1.311-discovery-json.jsonl")
        #expect(events.contains(.step("read discovery/notes.md")))
        guard case .done(let result) = events.last else { Issue.record("no done"); return }
        #expect(text(events) == result)
        #expect((try? JSONSerialization.jsonObject(with: Data(result.utf8))) != nil)
    }

    @Test func wholeMessageRunGivesStepsAndResult() throws {
        let events = try events("claude-2.1.311-read-only-run.jsonl")
        #expect(events.contains { if case .step(let s) = $0 { s.hasPrefix("read ") } else { false } })
        #expect(text(events).isEmpty)  // no deltas without --include-partial-messages
        guard case .done(let result) = events.last else { Issue.record("no done"); return }
        #expect(result.contains("questions"))
    }

    /// Recorded with write tools Mel never grants; still checks thinking, permission_denied and tool results stay silent.
    @Test func editRunsGiveOnlyStepsAndResult() throws {
        let short = try events("claude-2.1.311-edit-run-short.jsonl")
        #expect(short.count == 4)  // session, step, rate limit, done
        #expect(short[1] == .step("write"))
        #expect(short.last == .done(result: "done"))

        let long = try events("claude-2.1.311-edit-run-long.jsonl")
        let steps = long.compactMap { if case .step(let s) = $0 { s } else { nil } }
        #expect(steps == ["read src/lib.txt", "edit", "write", "write", "write", "read .git/config", "edit"])
        #expect(text(long).isEmpty)
        guard case .done(let result) = long.last else { Issue.record("no done"); return }
        #expect(result.contains("Succeeded"))
    }

    @Test func signedOut() throws {
        let events = try events("claude-2.1.311-signed-out.jsonl")
        #expect(events.last == .failed(.signedOut))
        #expect(text(events).isEmpty)
    }

    @Test func unknownResumeSession() throws {
        #expect(try events("claude-2.1.311-unknown-resume.jsonl").last == .failed(.sessionNotFound))
    }

    @Test func apiKeyFailsTheRun() {
        let line = #"{"type":"system","subtype":"init","session_id":"s1","apiKeySource":"ANTHROPIC_API_KEY"}"#
        #expect(claude.parse(line: line[...]) == [.session("s1"), .failed(.crashed(ClaudeCode.apiKeyMessage))])
    }

    @Test func rejectedRateLimit() {
        let line = #"{"type":"rate_limit_event","rate_limit_info":{"status":"rejected","resetsAt":1795448400}}"#
        #expect(claude.parse(line: line[...]) == [.rateLimit(allowed: false, resetsAt: Date(timeIntervalSince1970: 1795448400))])
    }

    @Test func failureTable() {
        #expect(ClaudeCode.reason(for: "Not logged in · Please run /login") == .signedOut)
        #expect(ClaudeCode.reason(for: "Claude AI usage limit reached") == .usageLimit(resetsAt: nil))
        #expect(ClaudeCode.reason(for: "No conversation found with session ID: abc") == .sessionNotFound)
        #expect(ClaudeCode.reason(for: "boom") == .crashed("boom"))
    }

    @Test func ignoresNoiseAndUnmappedRecords() {
        #expect(claude.parse(line: "not json") == [])
        #expect(claude.parse(line: #"{"type":"user","message":{"content":[]}}"#) == [])
        #expect(claude.parse(line: #"{"type":"system","subtype":"status","status":"requesting"}"#) == [])
    }
}
