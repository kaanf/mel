import Foundation
import Testing
@testable import MelSpec

struct V2FormatTests {
    @Test func intakeDecodesAllQuestionsAtOnce() throws {
        let reply = """
        ```json
        {"coverage":[{"label":"Goal","state":"covered"},{"label":"Payments","state":"notYet"}],
         "questions":[{"id":"payments","title":"How do members pay?","why":"Shapes checkout.","shapes":"requirements",
                       "options":[{"label":"Class packs","note":"From your idea","suggested":true},{"label":"At the desk"}]},
                      {"id":"offline","title":"Should the schedule work offline?"}]}
        ```
        """
        let intake = try Intake.decode(reply, size: .feature)
        #expect(intake.coverage.map(\.label) == ["Goal", "Payments"])
        #expect(intake.questions.count == 2)
        #expect(intake.questions[0].options == [Option(label: "Class packs", note: "From your idea", suggested: true), Option(label: "At the desk", note: "")])
        #expect(intake.questions[1].shapes == .requirements)   // the size's first file
        #expect(intake.questions.allSatisfy { $0.round == .intake && $0.answer == nil })
    }

    @Test func intakeTopicLeftToTheDraftDecodesAsLater() throws {
        let intake = try Intake.decode(#"{"coverage":[{"label":"Edge cases","state":"later"}],"questions":[]}"#, size: .feature)
        #expect(intake.coverage.map(\.state) == [.later])
        #expect(intake.name == nil)
    }

    @Test func intakeNameIsTrimmedAndBlankIsNone() throws {
        #expect(try Intake.decode(#"{"name":" Climb Slots ","coverage":[],"questions":[]}"#, size: .product).name == "Climb Slots")
        #expect(try Intake.decode(#"{"name":"  ","coverage":[],"questions":[]}"#, size: .product).name == nil)
    }

    @Test func analyzeDecodes() throws {
        let reply = """
        {"stats":[{"value":"14 of 15","label":"requirements have a task"}],
         "issues":[{"id":"i1","kind":"noTask","location":"REQUIREMENTS 2.2","text":"No task builds this.",
                    "actions":[{"label":"Move to Later","fix":"Set story 2 to P2.","files":["requirements"]},
                               {"label":"Add Task","fix":"Add a task for 2.2.","files":["tasks"]}]}],
         "coverage":[{"id":"2.2","text":"Studio cancels","screen":null,"architecture":"covered","task":"missing","test":"missing"}]}
        """
        let result = try AnalyzeResult.decode(reply)
        #expect(result.stats == [.init(value: "14 of 15", label: "requirements have a task")])
        #expect(result.issues[0].kind == .noTask)
        #expect(result.issues[0].actions[1].files == [.tasks])
        #expect(result.coverage[0].screen == nil)
        #expect(result.coverage[0].task == .missing)
    }

    @Test func analyzeInAJSONFenceDecodes() throws {
        let reply = "Here is the check.\n\n```json\n{\"stats\":[],\"issues\":[],\"coverage\":[]}\n```\n"
        let before = Date.now
        let result = try AnalyzeResult.decode(reply)
        #expect(result == AnalyzeResult(stats: [], issues: [], coverage: [], analyzedAt: result.analyzedAt))
        #expect(result.analyzedAt >= before)   // stamped by Mel on arrival
    }

    @Test func moduleNotesInParenthesesAreDropped() {
        let context = ProjectContext(product: "", tech: "", structure: "## Modules\n\n- FocusTimer (executable CLI) — Sources/FocusTimer\n- Core — Sources/Core", principles: "")
        #expect(context.modules.map(\.name) == ["FocusTimer", "Core"])
    }

    @Test func impactAndProjectContextDecode() throws {
        let impact = try ImpactResult.decode(#"{"items":[{"kind":"tasks","what":"Task 4","count":"1 task"}]}"#)
        #expect(impact.items == [.init(kind: .tasks, what: "Task 4", count: "1 task")])
        #expect(impact.title == "")
        #expect(try ImpactResult.decode(#"{"title":"Late cancel window is 12 hours","items":[]}"#).title == "Late cancel window is 12 hours")

        let context = try ProjectContext.decode(##"Here: {"product":"P","tech":"T","structure":"# Structure\n\n## Modules\n\n- Booking — `Sources/Booking`\n- Payments — Sources/Payments\n\n## Tests\n\n- Unit — Tests","principles":"R"}"##)
        #expect(context.modules == [Module(name: "Booking", path: "Sources/Booking"), Module(name: "Payments", path: "Sources/Payments")])
        #expect(context.promptText.hasPrefix("### .mel/project/product.md\n\nP\n\n### .mel/project/tech.md"))
    }

    @Test func decisionsRoundTripNewestFirst() throws {
        let date = try Date("2026-11-23T12:00:00Z", strategy: .iso8601)
        let decisions = [
            Decision(id: "D-03", title: "Cancellation window 12 hours", reason: "Your first answer in review.", source: "You", date: date, affects: ["1.3"]),
            Decision(id: "D-07", title: "Cancellation window 24 hours", reason: "Studio policy changed.\nTeachers need a day.", source: "You", date: date, replaces: "D-03", affects: ["1.3", "Q1"]),
        ]
        let text = Decision.markdown(decisions)
        #expect(text.hasPrefix("# Decisions\n\n## D-07 · Cancellation window 24 hours\n\nStudio policy changed.\nTeachers need a day.\n\n- Source: You · "))
        #expect(text.contains("- Replaces: D-03\n- Affects: 1.3, Q1"))

        let parsed = Decision.parse(text)
        #expect(parsed.map(\.id) == ["D-07", "D-03"])
        #expect(parsed[0].reason == "Studio policy changed.\nTeachers need a day.")
        #expect(parsed[0].replaces == "D-03")
        #expect(parsed[0].affects == ["1.3", "Q1"])
        #expect(parsed[0].source == "You")
        #expect(Calendar.current.isDate(parsed[0].date, inSameDayAs: date))
        #expect(parsed[1].replacedBy(in: parsed) == "D-07")
        #expect(Decision.nextID(after: parsed) == "D-08")
        #expect(Decision.nextID(after: []) == "D-01")
    }

    private let tasks = """
    # Tasks

    - [ ] 1. Booking data model and local store
      - Priority: P1
      - Covers: 1.1, 1.2
      - Reads: ARCHITECTURE › Data
      - Verify: `swift test --filter Booking`
    - [x] 2. Schedule screen
      - Priority: P2
      - Covers: Q1
      - Parallel with: 3
    """

    @Test func tasksParse() {
        let parsed = SpecTask.parse(tasks)
        #expect(parsed == [
            SpecTask(number: 1, title: "Booking data model and local store", priority: "P1", covers: ["1.1", "1.2"], reads: "ARCHITECTURE › Data", verify: "swift test --filter Booking"),
            SpecTask(number: 2, title: "Schedule screen", priority: "P2", covers: ["Q1"], reads: "", verify: "", parallelWith: [3]),
        ])
        #expect(parsed[0].promptFileName == "task-01.md")
    }

    @Test func taskPromptCarriesCriteriaInFull() {
        let requirements = "## 1. Book\n\n- 1.1 WHEN a member books, THE APP SHALL reserve a spot.\n"
        let prompt = SpecTask.parse(tasks)[0].prompt(requirements: requirements)
        #expect(prompt.hasPrefix("# Task 1 · Booking data model and local store\n\nPriority: P1\n"))
        #expect(prompt.contains("- 1.1 WHEN a member books, THE APP SHALL reserve a spot.\n- 1.2 (see REQUIREMENTS.md)"))
        #expect(prompt.contains("## Read first\n\nARCHITECTURE › Data"))
        #expect(prompt.contains("`swift test --filter Booking` passes"))
    }

    @Test func bugReportIdeaTextSkipsEmptyFields() {
        let report = BugReport(now: "Two taps book twice.", should: " One booking. ", where: "")
        #expect(report.ideaText == "Happens now: Two taps book twice.\nShould happen: One booking.")
        #expect(BugReport().ideaText == "")
    }

    @Test func agentsFileReplacesOnlyMelsBlock() {
        let block = "Specs live in specs/."
        #expect(AgentsFile.merge(existing: nil, block: block) == "<!-- mel:begin -->\nSpecs live in specs/.\n<!-- mel:end -->\n")
        #expect(AgentsFile.merge(existing: "# Rules\n\nBe nice.\n\n", block: block) == "# Rules\n\nBe nice.\n\n<!-- mel:begin -->\nSpecs live in specs/.\n<!-- mel:end -->\n")
        let existing = "# Rules\n\n<!-- mel:begin -->\nold\n<!-- mel:end -->\n\nMine.\n"
        #expect(AgentsFile.merge(existing: existing, block: "new") == "# Rules\n\n<!-- mel:begin -->\nnew\n<!-- mel:end -->\n\nMine.\n")
    }

    @Test func stepMarkersAndTrailer() {
        let reply = """
        # Requirements
        <!-- mel:step 1 -->

        ## 1. Book
        <!-- mel:step 2 -->
        - 1.1 THE APP SHALL book.

        <!-- mel:questions
        [{"id":"r2-1","title":"Should the waitlist expire?","options":[{"label":"Yes"},{"label":"No"}]},
         {"id":"r2-2","title":"A"},{"id":"r2-3","title":"B"},{"id":"r2-4","title":"C"}]
        -->
        """
        #expect(DraftText.step(in: reply) == 2)
        #expect(DraftText.strippingMarkers(reply) == "# Requirements\n\n## 1. Book\n- 1.1 THE APP SHALL book.\n")
        let questions = DraftText.questions(in: reply, kind: .requirements)
        #expect(questions.map(\.id) == ["r2-1", "r2-2", "r2-3"])
        #expect(questions.allSatisfy { $0.round == .draft && $0.shapes == .requirements })
        #expect(DraftText.questions(in: "# No trailer", kind: .tasks).isEmpty)
    }

    @Test func streamingHidesAHalfWrittenMarker() {
        #expect(DraftText.strippingMarkers("# Product\n\nText.\n<!-- mel:st") == "# Product\n\nText.\n")
        #expect(DraftText.step(in: "<!-- mel:step 3 -->\n<!-- mel:step 1") == 3)
    }

    @Test func openQuestionsComeFromCallouts() {
        let text = "> [!OPEN QUESTION]\n> Unused credits?\n\n> [!ASSUMPTION]\n> FIFO.\n\n> [!OPEN QUESTION]\n> Refunds?"
        #expect(OpenQuestion.parse(text, kind: .requirements) == [
            OpenQuestion(kind: .requirements, index: 0, text: "Unused credits?"),
            OpenQuestion(kind: .requirements, index: 1, text: "Refunds?"),
        ])
    }

    @Test(arguments: DocKind.allCases)
    func everyKindHasDraftSteps(_ kind: DocKind) {
        #expect(kind.draftSteps.count >= 5)
    }
}
