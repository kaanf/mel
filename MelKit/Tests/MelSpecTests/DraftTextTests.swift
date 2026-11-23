import Foundation
import Testing
@testable import MelSpec

struct DraftTextTests {
    @Test func stripsThePlanLine() {
        #expect(DraftText.file(fromReply: "5 stories\n\n# Requirements\n", kind: .requirements) == "# Requirements\n")
        #expect(DraftText.file(fromReply: "11 tasks\n# Tasks", kind: .tasks) == "# Tasks")
    }

    @Test func noFileTextUntilThePlanLineIsComplete() {
        #expect(DraftText.file(fromReply: "5 sto", kind: .requirements) == "")
    }

    @Test func keepsFilesWithoutAPlanLine() {
        #expect(DraftText.file(fromReply: "# Requirements\n", kind: .requirements) == "# Requirements\n")
        #expect(DraftText.file(fromReply: "1 Product\n", kind: .product) == "1 Product\n")
    }

    @Test func truncatesBeforeTheLastSection() {
        let text = "# Design\n\n## Stack\n\nSwift.\n\n## Data\n\nA spec has fo"
        #expect(DraftText.truncatedToLastCompleteSection(text) == "# Design\n\n## Stack\n\nSwift.\n\n")
    }

    @Test func truncateIgnoresHeadingsInCodeAndSubsections() {
        let text = "# Design\n\n## Stack\n\n```\n## not a heading\n```\n\n### Sub\n"
        #expect(DraftText.truncatedToLastCompleteSection(text) == "# Design\n\n")
        #expect(DraftText.truncatedToLastCompleteSection("# Design\n\nIntro") == "# Design\n\nIntro\n\n")
        #expect(DraftText.truncatedToLastCompleteSection("") == "")
    }

    private let doc = """
        # Requirements

        > [!ASSUMPTION]
        > The waitlist is first come,
        > first served.

        ```
        > [!ASSUMPTION]
        > In code, not counted.
        ```

        > [!ASSUMPTION]
        > Refunds go to the card.
        """

    @Test func confirmKeepsTheTextWithoutTheCallout() {
        let edited = DraftText.confirmAssumption(1, in: doc)
        #expect(edited?.contains("> Refunds") == false)
        #expect(edited?.hasSuffix("```\n\nRefunds go to the card.") == true)
        #expect(edited.map { MarkdownParser.summary($0, kind: .requirements).assumptions } == 1)
    }

    @Test func changeReplacesTheText() {
        let edited = DraftText.changeAssumption(0, to: "  Members choose a waitlist spot.\n", in: doc)
        #expect(edited?.hasPrefix("# Requirements\n\nMembers choose a waitlist spot.\n\n```") == true)
        #expect(edited.map { MarkdownParser.summary($0, kind: .requirements).assumptions } == 1)
    }

    @Test func unknownIndexIsNil() {
        #expect(DraftText.confirmAssumption(2, in: doc) == nil)
    }
}
