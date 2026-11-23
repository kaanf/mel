import Foundation
import Testing
@testable import MelSpec

struct MarkdownParserTests {
    /// This repo's own docs follow the spec format, so they double as real-looking samples.
    private func doc(_ name: String) throws -> String {
        let root = URL(filePath: #filePath).deletingLastPathComponent().appending(path: "../../../docs")
        return try String(contentsOf: root.appending(path: name), encoding: .utf8)
    }

    @Test func requirementsBlocks() {
        let text = """
        # Requirements

        ## 1. Book a class

        As a member, I want to book a class
        from the weekly schedule.

        - 1.1 WHEN a member books a class, THE APP SHALL reserve one spot.
        - 1.2 WHEN a class is full, THE APP SHALL offer the waitlist.
        - Not a criterion

        > [!ASSUMPTION]
        > The waitlist is first come, first served.
        """
        #expect(MarkdownParser.blocks(text) == [
            .heading(level: 1, text: "Requirements"),
            .heading(level: 2, text: "1. Book a class"),
            .paragraph("As a member, I want to book a class from the weekly schedule."),
            .criterion(id: "1.1", text: "WHEN a member books a class, THE APP SHALL reserve one spot."),
            .criterion(id: "1.2", text: "WHEN a class is full, THE APP SHALL offer the waitlist."),
            .listItem("Not a criterion"),
            .assumption(index: 0, text: "The waitlist is first come, first served."),
        ])
    }

    @Test func tasksWithCovers() {
        let text = """
        # Tasks

        - [ ] 1. Set up project skeleton
          - Covers: —
        - [x] 2. Weekly schedule screen
          - Covers: 1.1, 1.2
        - [ ] 3. No covers line
        """
        #expect(MarkdownParser.blocks(text) == [
            .heading(level: 1, text: "Tasks"),
            .task(id: "1", text: "Set up project skeleton", done: false, covers: []),
            .task(id: "2", text: "Weekly schedule screen", done: true, covers: ["1.1", "1.2"]),
            .task(id: "3", text: "No covers line", done: false, covers: []),
        ])
    }

    @Test func assumptionsAreIndexedInOrderAndKeepLines() {
        let text = """
        > [!ASSUMPTION]
        > First line.
        > Second line.
        Paragraph after.

        > [!assumption]
        > Another.
        """
        #expect(MarkdownParser.blocks(text) == [
            .assumption(index: 0, text: "First line.\nSecond line."),
            .paragraph("Paragraph after."),
            .assumption(index: 1, text: "Another."),
        ])
    }

    @Test func fencedCodeIsKeptVerbatim() {
        let text = "Intro\n```swift\n## not a heading\n- not a list\n```\n## Real"
        #expect(MarkdownParser.blocks(text) == [
            .paragraph("Intro"),
            .code("## not a heading\n- not a list"),
            .heading(level: 2, text: "Real"),
        ])
    }

    @Test func unterminatedCodeAndCRLF() {
        #expect(MarkdownParser.blocks("# A\r\n```\r\nx") == [.heading(level: 1, text: "A"), .code("x")])
    }

    @Test func plainListsAndQuotes() {
        #expect(MarkdownParser.blocks("1. First\n* Second\n> quoted\n#nospace") == [
            .orderedItem(number: 1, text: "First"),
            .listItem("Second"),
            .paragraph("quoted #nospace"),
        ])
    }

    @Test func emptyText() {
        #expect(MarkdownParser.blocks("").isEmpty)
        #expect(MarkdownParser.summary("", kind: .product) == DocSummary())
    }

    @Test func summaryOfRepoRequirements() throws {
        let s = MarkdownParser.summary(try doc("REQUIREMENTS.md"), kind: .requirements)
        #expect(s.stories == 9)
        #expect(s.criteria == 71)
        #expect(s.sections == 10)
        #expect(s.assumptions == 0)
    }

    @Test func summaryOfRepoTasks() throws {
        let s = MarkdownParser.summary(try doc("TASKS.md"), kind: .tasks)
        #expect(s.tasks == 42)
        #expect(s.stories == 0)
    }

    @Test func designHasSevenNumberedSectionsInSpecFormatSample() {
        let text = (1...7).map { "## \($0). Section" }.joined(separator: "\n\n")
        #expect(MarkdownParser.summary("# Design\n\n" + text, kind: .architecture).sections == 7)
    }

    @Test func repoTasksCoverEveryRepoCriterion() throws {
        #expect(MarkdownParser.uncoveredCriteria(requirements: try doc("REQUIREMENTS.md"), tasks: try doc("TASKS.md")).isEmpty)
    }

    @Test func uncoveredCriteriaInFileOrder() {
        let requirements = """
        - 1.1 THE APP SHALL a.
        - 1.2 THE APP SHALL b.
        - 2.1 THE APP SHALL c.
        """
        let tasks = "- [ ] 1. Do it\n  - Covers: 1.2"
        #expect(MarkdownParser.uncoveredCriteria(requirements: requirements, tasks: tasks) == ["1.1", "2.1"])
    }

    @Test func storiesAreNumberedSections() {
        let text = "## 1. Story\n\nAs a user, I want x.\n\n## 2. Another\n\nP2\n\n## Quality requirements\n\n- Q1 THE APP SHALL be fast."
        let s = MarkdownParser.summary(text, kind: .requirements)
        #expect(s.stories == 2)
        #expect(s.sections == 3)
        #expect(s.quality == 1)
    }

    private let v2Requirements = """
    # Requirements

    ## 1. Book a class

    P1 · MVP
    Source: your idea, Question 4 (cancellations)

    As a member, I want to book a class,
    so that my spot is guaranteed.

    - 1.1 WHEN a member books a class with free spots,
      THE APP SHALL reserve one spot.
    - 1.2 WHEN a class is full, THE APP SHALL offer the waitlist.

    > [!ASSUMPTION]
    > The waitlist is first come, first served.

    > [!OPEN QUESTION]
    > What happens to unused credits?

    <!-- MVP line -->

    ## 2. Gift cards

    P2
    Source: Question 2

    - 2.1 WHEN a member buys a gift card, THE APP SHALL email it.

    ## Quality requirements

    - Q1 THE APP SHALL open the schedule in under 1 second.
    - Q2 WHILE offline, THE APP SHALL show the last schedule.

    ## Edge cases

    - Two members book the last spot at once.
    <!-- mel:step 4 -->
    """

    @Test func v2RequirementsBlocks() {
        let blocks = MarkdownParser.blocks(v2Requirements)
        #expect(blocks.contains(.priority("P1", mvp: true)))
        #expect(blocks.contains(.priority("P2", mvp: false)))
        #expect(blocks.contains(.source("your idea, Question 4 (cancellations)")))
        #expect(blocks.contains(.criterion(id: "1.1", text: "WHEN a member books a class with free spots, THE APP SHALL reserve one spot.")))
        #expect(blocks.contains(.criterion(id: "Q2", text: "WHILE offline, THE APP SHALL show the last schedule.")))
        #expect(blocks.contains(.assumption(index: 0, text: "The waitlist is first come, first served.")))
        #expect(blocks.contains(.openQuestion(index: 0, text: "What happens to unused credits?")))
        #expect(blocks.contains(.mvpLine))
        #expect(blocks.last == .listItem("Two members book the last spot at once."))   // marker skipped
    }

    @Test func v2RequirementsSummary() {
        let s = MarkdownParser.summary(v2Requirements, kind: .requirements)
        #expect(s == DocSummary(stories: 2, mvpStories: 1, criteria: 3, quality: 2, sections: 4, assumptions: 1, openQuestions: 1))
    }

    @Test func experienceFlowsAndScreens() {
        let text = """
        # Experience

        ## Flow 1 · Book a class

        Covers: 1.1, 1.2

        1. Schedule (1.1)
        2. Class detail (1.1, 1.2)

        ## Screens and states

        | Screen | States | Criteria |
        |---|---|---|
        | Schedule | Default, Empty week, Offline | 1.1 |
        | Class detail | Default, Full, !Error | 1.1, 1.2 |

        ## Visual direction

        Calm and light.
        """
        let blocks = MarkdownParser.blocks(text)
        #expect(blocks.contains(.covers(["1.1", "1.2"])))
        #expect(blocks.contains(.orderedItem(number: 2, text: "Class detail (1.1, 1.2)")))
        #expect(blocks.contains(.table(header: ["Screen", "States", "Criteria"], rows: [
            ["Schedule", "Default, Empty week, Offline", "1.1"],
            ["Class detail", "Default, Full, !Error", "1.1, 1.2"],
        ])))
        let s = MarkdownParser.summary(text, kind: .experience)
        #expect(s.flows == 1)
        #expect(s.screens == 2)
        #expect(s.missingStates == 1)
    }

    @Test func wrappedTaskKeepsCovers() {
        let blocks = MarkdownParser.blocks("- [ ] 1. Build the\n  booking store\n  - Covers: 1.1")
        #expect(blocks == [.task(id: "1", text: "Build the booking store", done: false, covers: ["1.1"])])
    }
}
