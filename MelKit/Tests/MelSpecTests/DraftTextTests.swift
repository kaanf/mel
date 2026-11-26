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
}
