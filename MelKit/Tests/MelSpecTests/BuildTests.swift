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

        spec.started(1)
        #expect(spec.build == .building)
        #expect(spec.status(of: tasks[0], in: steps) == .running)
        spec.finished(1, passed: false, output: "BookingTest FAILED", of: tasks)
        #expect(spec.status(of: tasks[0], in: steps) == .failed("BookingTest FAILED"))
        spec.finished(1, passed: true, at: Date(timeIntervalSince1970: 0), of: tasks)
        #expect(spec.status(of: tasks[1], in: steps) == .ready)
        #expect(spec.status(of: tasks[2], in: steps) == .ready)

        spec.finished(2, passed: true, byHand: true, of: tasks)
        spec.finished(3, passed: true, of: tasks)
        #expect(spec.status(of: tasks[3], in: steps) == .ready)
        #expect(spec.status(of: tasks[4], in: steps) == .waiting("Starts after task 4. Both change shared/booking."))
    }

    @Test func theLastTaskMovesTheSpecToDoneAndReopenBack() {
        var spec = yoga
        for task in tasks { spec.finished(task.number, passed: true, of: tasks) }
        #expect(spec.build == .done)
        #expect(spec.doneCount(tasks) == 5)
        spec.reopen(3)
        #expect(spec.build == .building)
        #expect(spec.doneCount(tasks) == 4)
        spec.startOver()
        #expect(spec.runs == nil)
    }

    @Test func promptsNameOnlyWhatTheTaskNeeds() {
        #expect(tasks[0].buildPrompt(slug: "yoga", of: 5) == """
        Task 1 of 5 in specs/yoga.
        Read AGENTS.md first, then only: REQUIREMENTS.md 1.1 and 1.2, ARCHITECTURE.md › Data.
        Build: Booking data and local store (requirements 1.1, 1.2).
        Change only shared/booking.
        Done when this passes: ./gradlew :shared:allTests --tests "*Booking*"
        If the plan doesn’t fit what you find, stop and say why instead of changing the plan.
        """)
        #expect(tasks[0].fixPrompt(slug: "yoga", of: 5, output: "BookingTest > spot FAILED") == """
        Task 1 of 5 in specs/yoga: the check failed.
        ./gradlew :shared:allTests --tests "*Booking*"
        BookingTest > spot FAILED
        Fix the code in shared/booking so the check passes. Don’t change the tests or the plan.
        """)
    }
}
