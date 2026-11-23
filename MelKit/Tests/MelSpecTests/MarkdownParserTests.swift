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
            .listItem("First"),
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
        #expect(s.criteria == 66)
        #expect(s.sections == 10)
        #expect(s.assumptions == 0)
    }

    @Test func summaryOfRepoTasks() throws {
        let s = MarkdownParser.summary(try doc("TASKS.md"), kind: .tasks)
        #expect(s.tasks == 41)
        #expect(s.stories == 0)
    }

    @Test func designHasSixNumberedSectionsInSpecFormatSample() {
        let text = (1...6).map { "## \($0). Section" }.joined(separator: "\n\n")
        #expect(MarkdownParser.summary("# Design\n\n" + text, kind: .design).sections == 6)
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

    @Test func storiesNeedAsAParagraph() {
        let text = "## 1. Story\n\nAs a user, I want x.\n\n## 2. Not a story\n\nSomething else.\n\n## Unnumbered\n\nAs a user."
        let s = MarkdownParser.summary(text, kind: .requirements)
        #expect(s.stories == 1)
        #expect(s.sections == 3)
    }
}
