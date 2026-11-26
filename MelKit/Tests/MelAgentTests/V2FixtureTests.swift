import Foundation
import Testing
@testable import MelAgent

/// v2 runs of core's prompts, recorded with docs/research/v2-prompts/. Checks the stream and the
/// JSON keys only; core's decoders (`ProjectContext.decode`, `AnalyzeResult.decode`, …) get their own tests.
struct V2FixtureTests {
    let claude = ClaudeCode()

    func events(_ name: String) throws -> [AgentEvent] {
        try fixtureText("claude-2.1.311-\(name).jsonl").split(separator: "\n").flatMap { claude.parse(line: $0) }
    }

    func result(_ name: String) throws -> String {
        let events = try events(name)
        guard case .done(let result) = events.last else { throw Failure.noResult }
        #expect(events.map { if case .text(let t) = $0 { t } else { "" } }.joined() == result)
        return result
    }

    /// The reply's outermost `{…}`: analyze came back inside a ```json fence once.
    func object(_ name: String) throws -> [String: Any] {
        let reply = try result(name)
        let start = try #require(reply.firstIndex(of: "{")), end = try #require(reply.lastIndex(of: "}"))
        return try #require(JSONSerialization.jsonObject(with: Data(reply[start...end].utf8)) as? [String: Any])
    }

    enum Failure: Error { case noResult }

    @Test func projectContext() throws {
        let context = try object("project-context")
        #expect(Set(context.keys) == ["product", "tech", "structure", "principles", "read", "sources"])
        let structure = try #require(context["structure"] as? String)
        #expect(structure.contains("## Modules\n\n- FocusTimer — Sources/FocusTimer\n- TimerCore — Sources/TimerCore"))
    }

    @Test func intake() throws {
        let intake = try object("intake")
        let questions = try #require(intake["questions"] as? [[String: Any]])
        #expect((1...3).contains(questions.count))
        for question in questions {
            #expect(Set(question.keys) == ["id", "title", "why", "shapes", "options"])
        }
        let coverage = try #require(intake["coverage"] as? [[String: String]])
        #expect(coverage.allSatisfy { ["covered", "asking", "notYet", "later"].contains($0["state"]) })
    }

    /// Markers arrive split across deltas (`"<!-- m"`, `"-- mel:step 2"`), so stripping them needs a buffer.
    @Test func draftWithStepMarkersAndTrailer() throws {
        let events = try events("draft-steps")
        let deltas = events.compactMap { if case .text(let t) = $0 { t } else { nil } }
        #expect(deltas.contains("<!-- m"))
        let draft = try result("draft-steps")
        let markers = draft.matches(of: #/<!-- mel:step (\d+) -->/#).map { Int($0.1)! }
        #expect(markers == Array(1...7))
        let trailer = try #require(draft.firstMatch(of: #/<!-- mel:questions\n(.*)\n-->$/#.dotMatchesNewlines()))
        let questions = try #require(JSONSerialization.jsonObject(with: Data(trailer.1.utf8)) as? [[String: Any]])
        #expect((1...3).contains(questions.count))
        #expect(questions.allSatisfy { $0["shapes"] == nil })  // left out; DraftText.questions defaults it to the file's kind
    }

    @Test func analyze() throws {
        let analysis = try object("analyze")
        #expect((3...4).contains((analysis["stats"] as? [Any])?.count ?? 0))
        let issues = try #require(analysis["issues"] as? [[String: Any]])
        #expect(Set(issues.compactMap { $0["kind"] as? String }) == ["contradiction", "noTask", "qualityNotCovered", "scopeCreep"])
        #expect(issues.allSatisfy { ($0["actions"] as? [Any])?.count == 2 })
        let coverage = try #require(analysis["coverage"] as? [[String: Any]])
        #expect(coverage.allSatisfy { $0["screen"] is NSNull })  // Feature size: no EXPERIENCE.md
    }

    @Test func impact() throws {
        let items = try #require(try object("impact")["items"] as? [[String: String]])
        #expect(items.map { $0["kind"] } == ["tasks"])  // unaffected files are left out
        #expect(items.allSatisfy { Set($0.keys) == ["kind", "what", "count"] })
    }

    /// Recorded with `allowsTools: false` (`--tools ""`): files are inline, so one turn and no steps.
    @Test func analyzeImpactAndReviseRunWithoutTools() throws {
        for name in ["analyze", "impact", "revise"] {
            #expect(try fixtureText("claude-2.1.311-\(name).jsonl").contains(#""tools":[]"#))
            #expect(try events(name).allSatisfy { if case .step = $0 { false } else { true } })
        }
    }

    /// `result.usage` of the revise run: output 1364 + input 2 + cache creation 2957; its 649 cache-read tokens don't count (OQ #26).
    @Test func usageCountsOutputAndUncachedInput() throws {
        let events = try events("revise")
        #expect(events.dropLast().last == .usage(tokens: 4_323))
        #expect(events.count { if case .usage = $0 { true } else { false } } == 1)
    }

    /// Attachments under specs/<slug>/.mel/attachments/ open with Read under the read-only flags, images included.
    @Test func attachmentsAreReadable() throws {
        let events = try events("attachments")
        #expect(events.contains(.step("read attachments/crash.log")))
        #expect(events.contains(.step("read attachments/shot.png")))
        #expect(try result("attachments").contains("token expired (code 4012)"))
    }
}
