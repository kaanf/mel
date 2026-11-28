import Foundation
import Testing
@testable import MelSpec

struct ProjectSpecTests {
    private let schedule = """
        # Schedule

        How schedule works today.

        - B-2.1 WHEN a member opens the schedule, THEN it shows classes for the next 7 days.
        - B-2.2 WHEN a class is full,
          THEN it shows Full.
        """

    @Test func areasParseWithWrappedRules() throws {
        let area = try #require(ProjectSpec.area(file: "schedule.md", text: schedule))
        #expect(area.title == "Schedule")
        #expect(area.number == 2)
        #expect(area.rules == [.init(id: "B-2.1", text: "WHEN a member opens the schedule, THEN it shows classes for the next 7 days."),
                               .init(id: "B-2.2", text: "WHEN a class is full, THEN it shows Full.")])
        #expect(ProjectSpec.area(file: "schedule.md", text: area.markdown) == area)
    }

    @Test func scannedAreasAreNumbered() {
        let spec = ProjectSpec.numbered([("booking.md", "Booking", ["WHEN a, THEN b."]), ("schedule.md", "Schedule", ["WHEN c, THEN d.", "WHEN e, THEN f."])])
        #expect(spec.areas.map(\.number) == [1, 2])
        #expect(spec.rule("B-2.2")?.rule.text == "WHEN e, THEN f.")
    }

    /// V2-34: deltas from the criteria's tags, merged by id; an added rule takes its area's next id, a new area the next number.
    @Test func deltasMergeByID() throws {
        let today = ProjectSpec(areas: [try #require(ProjectSpec.area(file: "schedule.md", text: schedule))])
        let deltas = ProjectSpec.deltas(in: [
            ("1.1", "WHEN a member picks a teacher, THEN only that teacher’s classes show. `Adds schedule.md`"),
            ("2.1", "WHEN a member opens the schedule, THEN it shows 4 weeks. `Changes B-2.1`"),
            ("3.1", "WHEN a member taps a teacher, THEN a profile opens. `Adds teachers.md`"),
            ("Q1", "WHEN a class is full, THEN it shows Full. `Keeps B-2.2`"),
            ("4.1", "WHEN nothing, THEN nothing."),
        ])
        #expect(deltas.count == 4)
        let (merged, changes) = today.merging(deltas)
        #expect(changes.map(\.id) == ["B-2.3", "B-2.1", "B-3.1"])
        #expect(changes[1].before == "WHEN a member opens the schedule, THEN it shows classes for the next 7 days.")
        #expect(changes[2].newFile)
        #expect(merged.rule("B-2.1")?.rule.text == "WHEN a member opens the schedule, THEN it shows 4 weeks.")
        #expect(merged.areas.map(\.file) == ["schedule.md", "teachers.md"])
        #expect(merged.areas[1].title == "Teachers")
        #expect(today.merging([.removes(id: "B-2.2")]).spec.rule("B-2.2") == nil)
    }

    /// V2-31: a criterion that changes a rule asks which one holds; keeping this spec's changes nothing.
    @Test func changesHowItWorksTodayIsACard() throws {
        let today = ProjectSpec(areas: [try #require(ProjectSpec.area(file: "schedule.md", text: schedule))])
        let questions = Spec.todayQuestions(criteria: [("2.1", "WHEN a member opens the schedule, THEN it shows 4 weeks. `Changes B-2.1`")], file: .requirements, today: today)
        let question = try #require(questions.first)
        #expect(question.today == "B-2.1")
        #expect(question.options.map(\.label) == ["WHEN a member opens the schedule, THEN it shows 4 weeks.", "WHEN a member opens the schedule, THEN it shows classes for the next 7 days."])
        #expect(Card(question).topic == "Changes how it works today")

        var spec = Spec(name: "S", idea: "x", size: .feature, folder: URL(filePath: "/p/specs/s"), stage: .board, docs: [.requirements: .approved, .architecture: .locked, .tasks: .locked], questions: [question])
        spec.answer(card: question.id, .option(0, note: nil))
        #expect(spec.questions[0].pending == nil)
        spec.answer(card: question.id, .option(1, note: nil))
        #expect(spec.changeRequests.first?.contains("keeps today’s rule instead") == true)
    }
}

struct IssueDraftTests {
    /// V2-35: one issue per task, its criteria as a checklist (tags left out), the check, the phase as a milestone.
    @Test func issuesComeFromTheTasksAndTheirCriteria() {
        let task = SpecTask(number: 2, title: "Teacher filter", priority: "P1", covers: ["1.1", "Q1"], reads: "", verify: "swift test", changes: ["Sources/Schedule"], phase: "Filtering")
        let drafts = IssueDraft.drafts(tasks: [task], criteria: [("1.1", "WHEN a member picks a teacher, THEN only their classes show. `Adds schedule.md`"), ("Q1", "WHEN it filters, THEN it takes under 300 ms.")],
                                       slug: "filter", checklist: true, milestones: true)
        #expect(drafts.first?.title == "Teacher filter")
        #expect(drafts.first?.milestone == "Filtering")
        #expect(drafts.first?.body == "Task 2 of the spec `specs/filter` (planned with Mel).\n\n## Done when\n\n- [ ] 1.1 WHEN a member picks a teacher, THEN only their classes show.\n- [ ] Q1 WHEN it filters, THEN it takes under 300 ms.\n\n## Check\n\n`swift test`\n\n## Changes\n\n- `Sources/Schedule`")
        #expect(IssueDraft.drafts(tasks: [task], criteria: [], slug: "filter", checklist: false, milestones: false).first?.milestone == nil)
        #expect(IssueDraft.label(slug: "filter") == "mel · filter")
    }
}
