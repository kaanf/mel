import Foundation
import Testing
@testable import MelSpec

struct PromptTests {
    /// `{{key}}`s in a prompt, before `rules` is filled in.
    private func placeholders(_ prompt: Prompt) -> Set<String> {
        Set(Prompt.load(prompt.rawValue).matches(of: /\{\{(\w+)\}\}/).map { String($0.1) })
    }

    /// The sample reply line a prompt shows the agent (the first line starting with `start`).
    private func sample(_ text: String, startingWith start: String) throws -> String {
        try #require(text.split(separator: "\n").first { $0.hasPrefix(start) }).description
    }

    private static let drafting: Set<String> = ["project", "name", "idea", "files", "attachments", "answers", "decide", "approved", "steps", "rules"]

    @Test func placeholdersPerPrompt() {
        for kind in DocKind.allCases { #expect(placeholders(Prompt(drafting: kind)) == Self.drafting) }
        #expect(placeholders(.project) == ["mode"])
        #expect(placeholders(.intake) == ["size", "files", "project", "name", "idea", "attachments", "topics", "count", "kinds"])
        #expect(placeholders(.rewrite) == ["file", "files", "project", "name", "idea", "instruction", "approved", "current", "steps", "rules"])
        #expect(placeholders(.change) == ["files", "reading", "project", "name", "idea", "requests", "attachments", "current", "kinds", "rules"])
        #expect(placeholders(.analyze) == ["name", "approved", "earlier", "kinds"])
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
    func draftingPromptsAskForStepsAndShowTheFormat(_ kind: DocKind) {
        let text = Prompt(drafting: kind).build([:])
        #expect(text.contains("You are writing \(kind.fileName)"))
        #expect(text.contains("# \(kind.title)\n"))
        #expect(text.contains("## Steps"))
        #expect(!text.contains("mel:step"))   // no markers: the board shows no checklist
        #expect(text.contains("Never write TBD, TODO or placeholders."))
    }

    @Test func fillGapsPicksTheRules() {
        let on = Prompt.requirements.build([:])
        let off = Prompt.requirements.build([:], fillGaps: false)
        #expect(on.contains("wrap that decision in a `> [!ASSUMPTION]` callout"))
        #expect(off.contains("Do not make assumptions."))
        #expect(!off.contains("[!ASSUMPTION]"))
    }

    @Test func languageIsAppendedOnlyWhenSet() {
        let turkish = Prompt.intake.build([:], language: .turkish)
        #expect(turkish.contains("Write everything the user reads in Turkish"))
        #expect(turkish.hasPrefix(Prompt.intake.build([:])))
        #expect(!Prompt.intake.build([:]).contains("## Language"))
    }

    @Test(arguments: [true, false])
    func trailerSampleDecodes(_ fillGaps: Bool) {
        let text = Prompt.tasks.build([:], fillGaps: fillGaps)
        let start = text.range(of: "<!-- mel:questions")!.lowerBound
        let end = text.range(of: "-->", range: start..<text.endIndex)!.upperBound
        let questions = DraftText.questions(in: String(text[start..<end]), kind: .tasks)
        #expect(questions.count == 1)
        #expect(questions.first?.options.first?.suggested == true)
    }

    @Test func intakeSampleDecodes() throws {
        let line = try sample(Prompt.intake.build([:]), startingWith: #"{"name""#)
        let intake = try Intake.decode(line, size: .product)
        #expect(intake.name == "Class Pack Booking")
        #expect(intake.coverage[1].question == intake.questions.first?.id)
        #expect(intake.questions.first?.shapes == .requirements)
        #expect(intake.questions.first?.options.count == 2)
        #expect(intake.coverage.map(\.state) == [.covered, .notYet, .later])
    }

    @Test func analyzeAndProjectSamplesDecode() throws {
        let analyze = try AnalyzeResult.contradictions(in: sample(Prompt.analyze.build([:]), startingWith: #"{"issues":[{"#))
        #expect(analyze.first?.actions.count == 2)
        #expect(analyze.first?.ids == ["1.3"])
        let context = try ProjectContext.decode(sample(Prompt.project.build([:]), startingWith: #"{"product""#))
        #expect(context.modules == [Module(name: "Booking", path: "Sources/Booking")])
        #expect(context.read.first == ReadItem(label: "README.md", source: "Product summary"))
        #expect(context.sources["product.md"] == "From README")
    }

    @Test func stepsAndFilesText() {
        #expect(DocKind.spec.stepsText.hasPrefix("1. Read the report and the code it touches\n2. "))
        #expect(SpecSize.feature.filesText == "REQUIREMENTS.md, ARCHITECTURE.md, TASKS.md")
        #expect(SpecSize.quickFix.kindsText == "`spec`")
    }

    @Test func valuesAreNotExpandedTwice() {
        let text = Prompt.continue.build(["file": "TASKS.md", "partial": "Uses {{file}} literally"])
        #expect(text.contains("Uses {{file}} literally"))
        #expect(text.contains("writing TASKS.md was cut off"))
    }

    @Test func unknownKeysStay() {
        #expect(Prompt.continue.build([:]).contains("{{partial}}"))
    }

    /// Analyze runs without tools; the prompt must say so or Claude tries to read (platform finding).
    @Test func noToolsPromptsForbidReading() {
        #expect(Prompt.analyze.build([:]).contains("Do not read any files."))
    }
}
