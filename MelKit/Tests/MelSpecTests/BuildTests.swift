import Foundation
import Testing
@testable import MelSpec

/// V2-3 Build: the drawn example, tasks 1–5 in three steps.
struct BuildTests {
    let tasks = SpecTask.parse("""
    - [ ] 1. Booking data and local store
      - Covers: 1.1, 1.2
      - Reads: REQUIREMENTS.md 1.1 and 1.2, ARCHITECTURE.md › Data
      - Verify: `./gradlew :shared:allTests --tests "*Booking*"`
      - Changes: shared/booking
    - [ ] 2. Schedule and class screens
      - Verify: `./gradlew :androidApp:connectedCheck`
      - Changes: androidApp, iosApp
      - Parallel with: 3
    - [ ] 3. Class pack checkout
      - Changes: `shared/payments`
      - Parallel with: 2
    - [ ] 4. Cancel a booking
      - Changes: shared/booking
      - Parallel with: 5
    - [ ] 5. Waitlist
      - Changes: shared/booking
      - Parallel with: 4
    """)

    let yoga = Spec(name: "Yoga", idea: "x", size: .feature, folder: URL(filePath: "/tmp/yoga/specs/yoga"))

    @Test func stepsFollowParallelWithAndSharedFolders() {
        let steps = BuildStep.steps(tasks)
        #expect(steps.map(\.kind) == [.alone, .together, .inOrder])
        #expect(steps.map { $0.tasks.map(\.number) } == [[1], [2, 3], [4, 5]])
        #expect(tasks[2].changes == ["shared/payments"])
    }

    @Test func aStepOpensWhenTheOneBeforeIsDone() {
        var spec = yoga
        let steps = BuildStep.steps(tasks)
        #expect(spec.status(of: tasks[0], in: steps) == .ready)
        #expect(spec.status(of: tasks[1], in: steps) == .waiting("Starts after step 1 is done."))

        spec.started(1, prompt: "p1")
        #expect(spec.build == .building)
        #expect(spec.status(of: tasks[0], in: steps) == .running)
        spec.finished(1, passed: false, output: "BookingTest FAILED", prompt: "p1", of: tasks)
        #expect(spec.status(of: tasks[0], in: steps) == .failed("BookingTest FAILED"))
        spec.finished(1, passed: true, at: Date(timeIntervalSince1970: 0), prompt: "p1", of: tasks)
        #expect(spec.status(of: tasks[1], in: steps) == .ready)
        #expect(spec.status(of: tasks[2], in: steps) == .ready)

        spec.finished(2, passed: true, byHand: true, prompt: "p2", of: tasks)
        spec.finished(3, passed: true, prompt: "p3", of: tasks)
        #expect(spec.status(of: tasks[3], in: steps) == .ready)
        #expect(spec.status(of: tasks[4], in: steps) == .waiting("Starts after task 4. Both change shared/booking."))
    }

    @Test func theLastTaskMovesTheSpecToDoneAndReopenBack() {
        var spec = yoga
        for task in tasks { spec.finished(task.number, passed: true, prompt: "", of: tasks) }
        #expect(spec.build == .done)
        #expect(spec.doneCount(tasks) == 5)
        spec.reopen(3)
        #expect(spec.build == .building)
        #expect(spec.doneCount(tasks) == 4)
        spec.startOver()
        #expect(spec.runs == nil)
    }

    @Test func aChangedPromptIsNoticedAndAnAddedTaskReopensTheBuild() {
        var spec = yoga
        spec.started(1, prompt: "old")
        #expect(!spec.promptChanged(1, now: "old"))
        #expect(spec.promptChanged(1, now: "new"))
        // The check keeps the prompt that ran; a task never copied takes the current one.
        spec.finished(1, passed: true, prompt: "new", of: tasks)
        #expect(spec.promptChanged(1, now: "new"))
        spec.finished(2, passed: true, byHand: true, prompt: "two", of: tasks)
        #expect(!spec.promptChanged(2, now: "two"))
        #expect(!spec.promptChanged(3, now: "anything"))

        // The first copy's commit stays through a fix prompt and the check.
        spec.started(3, prompt: "three")
        spec.based(3, on: "abc")
        spec.finished(3, passed: false, output: "x", prompt: "three", of: tasks)
        spec.started(3, prompt: "three")
        spec.based(3, on: "def")
        #expect(spec.runs?[3]?.base == "abc")

        for task in tasks { spec.finished(task.number, passed: true, prompt: "", of: tasks) }
        #expect(spec.build == .done)
        let added = tasks + SpecTask.parse("- [ ] 6. Receipt email")
        spec.retasked(added)
        #expect(spec.build == .building)
        #expect(spec.taskCount == 6)
    }

    @Test func promptsNameOnlyWhatTheTaskNeeds() {
        #expect(tasks[0].buildPrompt(slug: "yoga", of: 5) == """
        Task 1 of 5 in specs/yoga.
        Read AGENTS.md first, then only: REQUIREMENTS.md 1.1 and 1.2, ARCHITECTURE.md › Data.
        Build: Booking data and local store (requirements 1.1, 1.2).
        Change only shared/booking.
        Done when this passes: ./gradlew :shared:allTests --tests "*Booking*"
        When it's done, commit with a Conventional Commits message (feat:, fix: …) whose last line is: Mel-Task: yoga/1
        If the plan doesn’t fit what you find, stop and say why instead of changing the plan.
        """)
        #expect(tasks[0].fixPrompt(slug: "yoga", of: 5, output: "BookingTest > spot FAILED") == """
        Task 1 of 5 in specs/yoga: the check failed.
        ./gradlew :shared:allTests --tests "*Booking*"
        BookingTest > spot FAILED
        Fix the code in shared/booking so the check passes. Don’t change the tests or the plan.
        Commit the fix with a Conventional Commits message whose last line is: Mel-Task: yoga/1
        """)
    }

    @Test func reportIsTheLastWorksObject() {
        let reply = """
        Done. I used {braces} in prose.

        ```json
        {"works":["Members can book a class."],"decisions":[{"title":"Random IDs","why":"No clashes offline.","instead":"Server numbers."}],"notDone":[""],"refused":["Editing README.md"]}
        ```
        """
        let report = BuildReport.parse(reply)
        #expect(report?.works == ["Members can book a class."])
        #expect(report?.decisions.first?.title == "Random IDs")
        #expect(report?.notDone.isEmpty == true)
        #expect(report?.refused == ["Editing README.md"])
        #expect(BuildReport.parse("No JSON here.") == nil)
    }

    @Test func runPromptAddsTheRulesToTheCopyPrompt() {
        let prompt = tasks[0].runPrompt(slug: "demo", of: 5)
        #expect(prompt.hasPrefix(tasks[0].buildPrompt(slug: "demo", of: 5)))
        #expect(prompt.contains(#"{"works""#))
    }

    @Test func aStoppedRunIsStopped() {
        var spec = yoga
        spec.runs = [1: TaskRun(state: .stopped)]
        #expect(spec.status(of: tasks[0], in: BuildStep.steps(tasks)) == .stopped)
    }

    @Test func aRunCanStopOnAQuestion() {
        let reply = """
        I need one answer first.
        {"question":{"title":"What should members see offline?","why":"Members open it on the way.","options":[{"label":"The last schedule","means":"Booking still needs a connection.","suggested":true},{"label":"You’re offline"}]}}
        """
        let question = BuildQuestion.parse(reply)
        #expect(question?.title == "What should members see offline?")
        #expect(question?.options.map(\.label) == ["The last schedule", "You’re offline"])
        #expect(question?.options.first?.suggested == true)
        #expect(BuildQuestion.parse(#"{"works":[]}"#) == nil)

        var spec = yoga
        spec.runs = [1: TaskRun(state: .running)]
        spec.runs?[1]?.question = question
        #expect(spec.status(of: tasks[0], in: BuildStep.steps(tasks)) == .asking(question!))
        #expect(tasks[0].answerPrompt("The last schedule").contains("My answer: The last schedule"))
    }
}
