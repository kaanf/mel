import Testing
@testable import MelSpec

struct RoadmapTests {
    @Test func phasesFromHeadings() {
        let tasks = SpecTask.parse("""
            # Tasks

            ## 1 · Foundation

            - [ ] 1. Booking store
              - Priority: P1
            ## 2 · Booking and paying

            - [ ] 2. Schedule screens
              - Priority: P1
            - [ ] 3. Checkout
              - Priority: P2
            """)
        #expect(tasks.map(\.phase) == ["Foundation", "Booking and paying", "Booking and paying"])
        let phases = RoadmapPhase.phases(tasks)
        #expect(phases.map(\.name) == ["Foundation", "Booking and paying"])
        #expect(phases.map { $0.tasks.map(\.number) } == [[1], [2, 3]])
    }

    @Test func withoutHeadingsGroupsByPriority() {
        let tasks = [SpecTask(number: 1, title: "A", priority: "P2", covers: [], reads: "", verify: ""),
                     SpecTask(number: 2, title: "B", priority: "P1", covers: [], reads: "", verify: ""),
                     SpecTask(number: 3, title: "C", priority: "P1", covers: [], reads: "", verify: "")]
        let phases = RoadmapPhase.phases(tasks)
        #expect(phases.map(\.name) == ["P1", "P2"])
        #expect(phases.map { $0.tasks.map(\.number) } == [[2, 3], [1]])
    }

    @Test func flowsWithStatesAndBranches() {
        let flows = ExperienceFlow.parse(MarkdownParser.blocks("""
            # Experience

            ## Flow 1 · Book a class

            Covers: 1.1, 1.2

            1. Schedule (1.1)
            2. Class detail (1.1, 1.2)

            - Class is full: Waitlist sheet (1.2)

            ## Screens and states

            | Screen | States | Criteria |
            |---|---|---|
            | Schedule | Default, Loading, !Offline | 1.1 |
            """))
        #expect(flows.count == 1)
        let flow = flows[0]
        #expect(flow.title == "Book a class")
        #expect(flow.covers == ["1.1", "1.2"])
        #expect(flow.screens.map(\.name) == ["Schedule", "Class detail"])
        #expect(flow.screens[1].ids == ["1.1", "1.2"])
        #expect(flow.screens[0].states == ["Default", "Loading", "!Offline"])
        #expect(flow.screens[1].states.isEmpty)
        #expect(flow.branches == [ExperienceFlow.Branch(when: "Class is full", to: "Waitlist sheet", ids: ["1.2"])])
    }
}
