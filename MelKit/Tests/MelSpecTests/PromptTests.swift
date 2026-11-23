import Foundation
import Testing
@testable import MelSpec

struct PromptTests {
    /// `{{key}}`s in a prompt, before `rules` is filled in.
    private func placeholders(_ prompt: Prompt) -> Set<String> {
        Set(Prompt.load(prompt.rawValue).matches(of: /\{\{(\w+)\}\}/).map { String($0.1) })
    }

    @Test func placeholdersPerPrompt() {
        #expect(placeholders(.discovery) == ["name", "idea", "answers", "coverage"])
        #expect(placeholders(.product) == ["name", "idea", "answers", "decide", "rules"])
        #expect(placeholders(.requirements) == ["name", "idea", "answers", "decide", "approved", "rules"])
        #expect(placeholders(.design) == ["name", "idea", "answers", "decide", "approved", "rules"])
        #expect(placeholders(.tasks) == ["name", "idea", "decide", "approved", "rules"])
        #expect(placeholders(.continue) == ["file", "partial"])
    }

    @Test(arguments: Prompt.allCases)
    func buildFillsEveryPlaceholder(_ prompt: Prompt) {
        let values = Dictionary(uniqueKeysWithValues: placeholders(prompt).map { ($0, "<\($0)>") })
        let text = prompt.build(values)
        #expect(!text.contains("{{"))
        #expect(values.keys.filter { $0 != "rules" }.allSatisfy { text.contains("<\($0)>") })
    }

    @Test(arguments: DocKind.allCases)
    func draftingPromptsCarryTheCompletenessRule(_ kind: DocKind) {
        let text = Prompt(drafting: kind).build([:])
        #expect(text.contains("Never write open questions, TBD, TODO or placeholders."))
        #expect(text.contains("> [!ASSUMPTION]"))
        #expect(text.contains("# \(kind.title)"))
    }

    @Test func planLineOnlyForRequirementsAndTasks() {
        #expect(Prompt.requirements.build([:]).contains("`5 stories`"))
        #expect(Prompt.tasks.build([:]).contains("`11 tasks`"))
        #expect(!Prompt.product.build([:]).contains("plan line giving"))
        #expect(!Prompt.design.build([:]).contains("plan line giving"))
    }

    @Test func discoveryAsksForJSONWithoutAQuestionLimit() {
        let text = Prompt.discovery.build([:])
        #expect(text.contains("There is no limit on the number of questions."))
        #expect(text.contains("Reply with one JSON object only"))
    }

    @Test func discoveryRunsPhaseByPhaseWithAnOpenQuestionFirst() throws {
        let text = Prompt.discovery.build([:])
        #expect(text.contains("Work phase by phase in file order: `product`, `requirements`, `design`, `tasks`."))
        #expect(text.contains("Open each phase with an open question"))
        #expect(text.contains("only into the current phase or a later one"))
        #expect(text.contains("main screens and navigation, visual style and tone, and reference apps"))
        // The sample reply must decode, so the agent copies a shape Mel can read.
        let sample = try #require(text.split(separator: "\n").first { $0.hasPrefix(#"{"coverage""#) })
        let turn = try DiscoveryTurn.decode(String(sample))
        #expect(turn.coverage.map(\.phase) == [.product, .requirements, .requirements, .design])
        #expect(turn.next?.options.count == 2)
    }

    @Test func designStartsWithUserExperienceInSevenSections() {
        let text = Prompt.design.build([:])
        #expect(text.contains("# Design\n\n## 1. User experience\n## 2. Architecture"))
        #expect(text.contains("## 7. Testing strategy"))
        #expect(text.contains("Use exactly these seven sections"))
    }

    @Test func valuesAreNotExpandedTwice() {
        let text = Prompt.continue.build(["file": "DESIGN.md", "partial": "Uses {{file}} literally"])
        #expect(text.contains("Uses {{file}} literally"))
        #expect(text.contains("writing DESIGN.md was cut off"))
    }

    @Test func unknownKeysStay() {
        #expect(Prompt.continue.build([:]).contains("{{partial}}"))
    }
}
