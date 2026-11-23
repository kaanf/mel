import Foundation
import Testing
import MelSpec
@testable import MelAgent

/// core's decoders against the real v2 runs in V2FixtureTests.
struct V2DecodeTests {
    let fixtures = V2FixtureTests()

    @Test func projectContextDecodes() throws {
        let context = try ProjectContext.decode(fixtures.result("project-context"))
        #expect(context.modules.map(\.name).prefix(2) == ["FocusTimer", "TimerCore"])
    }

    @Test func intakeDecodes() throws {
        let intake = try Intake.decode(fixtures.result("intake"), size: .feature)
        #expect(!intake.questions.isEmpty)
        #expect(!intake.coverage.isEmpty)
    }

    @Test func draftStripsMarkersAndReadsTheTrailer() throws {
        let reply = try fixtures.result("draft-steps")
        #expect(DraftText.step(in: reply) == 7)
        let file = DraftText.file(fromReply: reply, kind: .requirements)
        #expect(file.hasPrefix("# Requirements"))
        #expect(!file.contains("<!-- mel:"))
        #expect(file.contains("\n\n<!-- MVP line -->\n\n"))
        #expect(!file.contains("\n\n\n"))
        #expect((1...3).contains(DraftText.questions(in: reply, kind: .requirements).count))
        let summary = MarkdownParser.summary(file, kind: .requirements)
        #expect(summary.stories >= 4)
        #expect(summary.mvpStories >= 1)
        #expect(summary.quality >= 1)
        #expect(MarkdownParser.blocks(file).contains(.mvpLine))

        // Streamed: every accumulated prefix shows no marker text and a step that never goes back.
        var text = ""
        var step = 0
        for case .text(let delta) in try fixtures.events("draft-steps") {
            text += delta
            #expect(!DraftText.file(fromReply: text, kind: .requirements).contains("<!-- mel:"))
            let now = DraftText.step(in: text)
            #expect(now >= step)
            step = now
        }
    }

    @Test func analyzeAndImpactDecode() throws {
        let analysis = try AnalyzeResult.decode(fixtures.result("analyze"))
        #expect(analysis.stats.count == 4)
        #expect(Set(analysis.issues.map(\.kind)) == [.contradiction, .noTask, .qualityNotCovered, .scopeCreep])
        #expect(analysis.coverage.allSatisfy { $0.screen == nil })
        let impact = try ImpactResult.decode(fixtures.result("impact"))
        #expect(impact.items.map(\.kind) == [.architecture, .tasks])
    }
}
