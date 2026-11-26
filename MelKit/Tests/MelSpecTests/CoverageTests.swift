import Testing
@testable import MelSpec

struct CoverageTests {
    private let requirements = """
    # Requirements

    ## 1. Book a class

    P1 · MVP
    Source: your idea

    As a member, I want to book a class, so that I have a spot.

    - 1.1 WHEN a member taps Book, THE APP SHALL reserve a spot.
    - 1.2 WHEN a class is full, THE APP SHALL offer the waitlist.

    ## 2. Buy a pack

    P1 · MVP

    As a member, I want to buy a class pack, so that I can book without paying each time.

    - 2.1 WHEN a member completes payment, THE APP SHALL add the pack's credits.

    <!-- MVP line -->

    ## 3. Gift cards

    P2

    As a member, I want to buy a gift card, so that I can give classes to a friend.

    - 3.1 WHEN a member completes payment, THE APP SHALL email the gift card.
    - 3.2 WHEN a gift card is redeemed, THE APP SHALL add its credits.

    ## Quality requirements

    - Q1 THE APP SHALL open the schedule in under 1 second.
    - Q2 WHILE offline, THE APP SHALL show the last loaded schedule.

    ## Edge cases

    - Two members book the last spot at once: one gets it.

    """

    private let experience = """
    # Experience

    ## Flow 1 · Book a class

    Covers: 1.1, Q1

    1. Schedule (1.1)
    2. Confirm booking (1.1)

    ## Flow 2 · Buy a pack

    Covers: 2.1

    1. Packs (2.1)

    ## Screens and states

    | Screen | States | Criteria |
    |---|---|---|
    | Schedule | Default, Loading | 1.1 |
    | Packs | Default | 2.1 |
    | Checkout | Default, Error | 2.1 |
    | Gift card | Default | 3.1, 3.2 |
    | About | Default | |

    """

    private let tasks = """
    # Tasks

    - [ ] 1. Booking store
      - Priority: P1
      - Covers: 1.1, Q1
      - Reads: ARCHITECTURE › Data
      - Verify: `swift test --filter Booking`
    - [ ] 2. Waitlist
      - Priority: P1
      - Covers: 1.2, 3.1
      - Reads: ARCHITECTURE › Data
    - [ ] 3. Gift card mail
      - Priority: P2
      - Covers: 3.1
      - Verify: `swift test --filter Gift`
      - Parallel with: 1

    """

    @Test func coverageByID() {
        let result = AnalyzeResult.coverage(requirements: requirements, experience: experience, tasks: tasks)
        #expect(result.coverage.map(\.id) == ["1.1", "1.2", "2.1", "3.1", "3.2", "Q1", "Q2"])
        #expect(result.coverage[0].text == "WHEN a member taps Book, THE APP SHALL reserve a spot.")
        #expect(result.coverage.map(\.task) == [.covered, .covered, .missing, .covered, nil, .covered, .missing])
        // 1.2's only task has no Verify; 3.1 has one in task 3.
        #expect(result.coverage.map(\.test) == [.covered, .missing, .missing, .covered, nil, .covered, .missing])
        #expect(result.coverage.map(\.screen) == [.covered, .missing, .covered, .covered, .covered, .covered, nil])
        #expect(result.coverage.allSatisfy { $0.architecture == nil })
        #expect(result.stats == [
            .init(value: "2 of 3", label: "P1 criteria have a task"),
            .init(value: "1 of 2", label: "quality requirements have a task"),
            .init(value: "4 of 5", label: "screens trace to a criterion"),
        ])
    }

    @Test func missingTasksBecomeIssuesWithTwoActions() {
        let issues = AnalyzeResult.coverage(requirements: requirements, experience: experience, tasks: tasks).issues
        #expect(issues.map(\.id) == ["task-2.1", "task-Q2"])
        #expect(issues.map(\.kind) == [.noTask, .qualityNotCovered])
        #expect(issues.map(\.location) == ["REQUIREMENTS 2.1", "REQUIREMENTS Q2"])
        #expect(issues.allSatisfy { $0.actions.count == 2 && $0.actions[0].files == [.requirements] && $0.actions[1].files == [.tasks] })
        #expect(issues[0].actions[1].fix == "Add a task that covers criterion 2.1.")
    }

    @Test func withoutExperienceThereIsNoScreenColumn() {
        let result = AnalyzeResult.coverage(requirements: requirements, experience: nil, tasks: tasks)
        #expect(result.coverage.allSatisfy { $0.screen == nil })
        #expect(result.stats.count == 2)
    }

    @Test func storyWithoutATagLineCountsAsP1() {
        let result = AnalyzeResult.coverage(requirements: "# Requirements\n\n## 1. Fix\n\n- 1.1 THE APP SHALL not crash.\n", experience: nil, tasks: "# Tasks\n")
        #expect(result.issues.map(\.id) == ["task-1.1"])
        #expect(result.stats == [.init(value: "0 of 1", label: "P1 criteria have a task")])
    }

    @Test func contradictionsComeFirstAndMarkTheirRows() throws {
        var result = AnalyzeResult.coverage(requirements: requirements, experience: experience, tasks: tasks)
        result.add(try AnalyzeResult.contradictions(in: #"{"issues":[{"id":"c1","location":"REQUIREMENTS 1.1 · EXPERIENCE › Schedule","text":"One spot against two.","ids":["1.1"],"actions":[{"label":"One","fix":"a","files":["experience","architecture"]},{"label":"Two","fix":"b","files":["requirements"]}]},{"id":"c2","location":"ARCHITECTURE › Data","text":"Two file names.","actions":[{"label":"A","fix":"a","files":["tasks"]},{"label":"B","fix":"b","files":["architecture"]}]}]}"#))
        #expect(result.issues.map(\.id) == ["c1", "c2", "task-2.1", "task-Q2"])
        #expect(result.issues.prefix(2).allSatisfy { $0.kind == .contradiction })
        #expect(result.stats.last == .init(value: "2", label: "contradictions between files"))
        #expect(result.coverage[0].screen == .conflict)
        #expect(result.coverage[0].architecture == .conflict)
        #expect(result.coverage[0].task == .covered)
        #expect(result.coverage.dropFirst().allSatisfy { $0.architecture == nil && $0.screen != .conflict })

        var clean = AnalyzeResult.coverage(requirements: requirements, experience: nil, tasks: tasks)
        clean.add([])
        #expect(clean.stats.last == .init(value: "0", label: "contradictions between files"))
    }

    // MARK: - Removing a story

    @Test func removalFindsWhatGoesWithTheStory() throws {
        let removal = try #require(StoryRemoval(story: "3", requirements: requirements, experience: experience, tasks: tasks))
        #expect(removal.title == "Gift cards")
        #expect(removal.criteria == ["3.1", "3.2"])
        #expect(removal.screens == ["Gift card"])
        #expect(removal.tasks == [3])
        #expect(removal.sharedTasks == [2])
        #expect(removal.summary == "Also removes requirements 3.1 and 3.2, 1 screen in EXPERIENCE.md and task 3.")
        #expect(!removal.requirements.contains("Gift"))
        #expect(removal.requirements.contains("<!-- MVP line -->\n\n## Quality requirements"))
        #expect(removal.requirements.contains("- 2.1 WHEN"))
        #expect(removal.instruction(for: .requirements) == nil)
        #expect(removal.section.hasPrefix("## 3. Gift cards\n\nP2\n"))
        #expect(removal.section.hasSuffix("add its credits."))
        #expect(removal.instruction(for: .product)?.hasSuffix("Remove the lines that described only this story.") == true)
        #expect(removal.instruction(for: .tasks) == "Story 3 “Gift cards” was removed from REQUIREMENTS.md, with criteria 3.1 and 3.2. Remove task 3. In task 2, remove its IDs from Covers and the work that served only them. Renumber the tasks so there are no gaps, in `Parallel with` too.")
        #expect(removal.instruction(for: .experience)?.contains("Remove the screen Gift card.") == true)
        #expect(removal.instruction(for: .architecture)?.hasPrefix("Story 3 “Gift cards” was removed") == true)
    }

    @Test func removingTheLastMVPStoryKeepsTheMVPLine() throws {
        let removal = try #require(StoryRemoval(story: "2", requirements: requirements, experience: nil, tasks: tasks))
        #expect(removal.criteria == ["2.1"])
        #expect(removal.requirements.contains("offer the waitlist.\n\n<!-- MVP line -->\n\n## 3. Gift cards"))
        #expect(removal.screens.isEmpty)
        #expect(removal.tasks.isEmpty)
        #expect(removal.summary == "Also removes requirement 2.1.")
        #expect(removal.instruction(for: .tasks) == nil)
    }

    @Test func unknownStoryIsNil() {
        #expect(StoryRemoval(story: "9", requirements: requirements, experience: nil, tasks: tasks) == nil)
        #expect(StoryRemoval(story: "1", requirements: requirements.replacing("## 1. ", with: "## 10. "), experience: nil, tasks: tasks) == nil)
    }
}
