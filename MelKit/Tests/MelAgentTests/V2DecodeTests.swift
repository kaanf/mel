import Foundation
import Testing
import MelSpec
@testable import MelAgent

/// core's decoders against the real v2 runs in V2FixtureTests.
struct V2DecodeTests {
    let fixtures = V2FixtureTests()

    @Test func projectContextDecodes() throws {
        let context = try ProjectContext.decode(fixtures.result("project-context"))
        #expect(context.modules.map(\.path).prefix(2) == ["Sources/FocusTimer", "Sources/TimerCore"])
        #expect(context.modules.map(\.name).prefix(2) == ["FocusTimer", "TimerCore"])
        #expect(context.read.first?.label == "README.md")
        #expect(context.read.count == 6)
        #expect(Set(context.sources.keys) == ["product.md", "tech.md", "structure.md", "principles.md"])
    }

    @Test func intakeDecodes() throws {
        let intake = try Intake.decode(fixtures.result("intake"), size: .feature)
        #expect(!intake.questions.isEmpty)
        #expect(!intake.coverage.isEmpty)
        #expect(intake.coverage.contains { $0.state == .later })  // topics no question covers
        #expect(!(intake.name ?? "").isEmpty)
        let ids = Set(intake.questions.map(\.id))
        #expect(intake.coverage.filter { $0.state == .notYet }.allSatisfy { $0.question.map(ids.contains) == true })
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
        // The planted contradiction (`config.json` in REQUIREMENTS, `settings.json` in the other two) comes first.
        let contradictions = try AnalyzeResult.contradictions(in: fixtures.result("analyze"))
        #expect(contradictions.first?.text.contains("settings.json") == true)
        #expect(contradictions.first?.ids?.contains("5.1") == true)
        #expect(contradictions.allSatisfy { $0.actions.count == 2 })
        #expect(Set(contradictions.flatMap(\.actions).flatMap(\.files)).isSubset(of: [.requirements, .architecture, .tasks]))
        let impact = try ImpactResult.decode(fixtures.result("impact"))
        #expect(impact.items.map(\.kind) == [.tasks])
        #expect(!impact.title.isEmpty)
    }

    /// The recorded change run had two requests against REQUIREMENTS, ARCHITECTURE and TASKS; only REQUIREMENTS states them.
    @Test func changeDecodes() throws {
        let change = try Change.decode(fixtures.result("change"))
        #expect(change.edits.count == 9)
        #expect(change.files(in: SpecSize.feature.files) == [.requirements])
        #expect(change.edits.contains { $0.old == "is a multiple of 4" && $0.new == "is a multiple of 3" })
        #expect(change.edits.allSatisfy { $0.old.count < 60 })   // short passages, not whole sections
        #expect(change.summary(order: SpecSize.feature.files) == "Changed 9 places in REQUIREMENTS.md")
    }

    /// The recorded revise run answered a round-2 question and an open question about this file.
    @Test func revisePatchDecodesAndPlacesEveryEdit() throws {
        let file = """
        # Requirements

        ## 1. Book a class

        P1 · MVP
        Source: your idea

        As a member, I want to book a class, so that I have a spot.

        - 1.1 WHEN a member taps Book, THE APP SHALL reserve a spot.

        ## 2. Buy a pack

        P1 · MVP
        Source: Question 1 (payments)

        As a member, I want to buy a class pack, so that I can book without paying each time.

        - 2.1 WHEN a member completes payment, THE APP SHALL add the pack's credits.

        <!-- MVP line -->

        > [!ASSUMPTION]
        > Packs expire after 6 months.

        ## Quality requirements

        - Q1 THE APP SHALL open the schedule in under 1 second.

        ## Edge cases

        - Two members book the last spot at once: one gets it.

        """
        let patch = try Patch.decode(fixtures.result("revise"))
        #expect(patch.edits.count == 2)
        let edited = try #require(patch.apply(to: file))
        #expect(edited.contains("## 3. Join a waitlist"))
        #expect(edited.contains("valid for 12 months"))
        #expect(!edited.contains("Packs expire after 6 months."))
        #expect(edited.hasPrefix(file.prefix(while: { $0 != "2" })))
    }
}
