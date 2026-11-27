import Foundation
import Testing
@testable import MelSpec

struct BoardTests {
    private func question(_ id: String, _ kind: DocKind, round: QuestionRound = .draft, about: String? = nil) -> Question {
        Question(id: id, title: "\(id)?", why: "", shapes: kind, round: round,
                 options: round == .open ? [] : [Option(label: "Yes", note: ""), Option(label: "No", note: "", suggested: true)], about: about)
    }

    private func feature(_ intake: [Question] = []) -> Spec {
        Spec(name: "Yoga", idea: "x", size: .feature, folder: URL(filePath: "/tmp/yoga/specs/yoga"), questions: intake)
    }

    /// Runs `step` to its end, as the session does.
    private func run(_ spec: inout Spec, asked: [Question] = [], check: AnalyzeResult = AnalyzeResult(stats: [], issues: [], coverage: [])) {
        guard let step = spec.nextStep else { Issue.record("nothing to run"); return }
        spec.begin(step)
        switch step {
        case .draft(let kind): spec.drafted(kind, asked: asked)
        case .change: spec.changed()
        case .check: spec.checked(check)
        }
    }

    private let contradiction = AnalyzeResult.Issue(id: "c1", kind: .contradiction, location: "REQUIREMENTS 1.3 · TASKS 4", text: "12 hours against 24.", actions: [
        .init(label: "Use 24 Hours", fix: "Change criterion 1.3 to 24 hours.", files: [.requirements]),
        .init(label: "Use 12 Hours", fix: "Change task 4 to 12 hours.", files: [.tasks]),
    ])

    // MARK: Intake

    @Test func intakeAsksOneAtATimeThenTheBoardStarts() {
        var spec = feature([question("pay", .requirements, round: .intake), question("phones", .requirements, round: .intake)])
        #expect(spec.nextStep == nil)
        #expect(spec.intakeCard?.id == "pay")
        #expect(spec.intakeCard?.file == nil)
        spec.answer(card: "pay", .text("Class packs"))
        #expect(spec.intakeCard?.id == "phones")
        #expect(spec.changeRequests.isEmpty)   // nothing is written yet: the draft reads the answers

        // "Skip, write the plan now": the rest are guesses.
        spec.startBoard()
        #expect(spec.stage == .board)
        #expect(spec.questions.map(\.answer) == [.text("Class packs"), .agentDecides])
        #expect(spec.intakeCard == nil)
        #expect(spec.cards.isEmpty)
        #expect(spec.nextStep == .draft(.requirements))
    }

    // MARK: Gating

    @Test func nextFileWaitsForTheCardsThenAnswersGoInAsOneChange() {
        var spec = feature()
        spec.startBoard()
        spec.begin(.draft(.requirements))
        #expect(spec.fileState(.requirements) == .writing)
        #expect(spec.fileState(.architecture) == .waiting)
        spec.drafted(.requirements, asked: [question("requirements-studio", .requirements, about: "cancelling"), question("requirements-open-0", .requirements, round: .open)])

        #expect(spec.cards.map(\.id) == ["requirements-studio", "requirements-open-0"])
        #expect(spec.cards[0].location == "REQUIREMENTS.md · about cancelling")
        #expect(spec.cards[1].location == "REQUIREMENTS.md")
        #expect(spec.fileState(.requirements) == .needsYou)
        #expect(spec.nextStep == nil)
        #expect(spec.gate?.file == .architecture)
        #expect(spec.gate?.answers == 2)

        spec.answer(card: "requirements-studio", .option(0, note: nil))
        #expect(spec.nextStep == nil)   // one card still open: answers are applied together
        #expect(spec.gate?.answers == 1)
        spec.answer(card: "requirements-open-0", .text("First on the waitlist"))
        #expect(spec.gate == nil)
        #expect(spec.fileState(.requirements) == .ready)
        #expect(spec.nextStep == .change)
        #expect(spec.changeRequests == [
            "REQUIREMENTS.md asked “requirements-studio?”. The answer: Yes",
            "REQUIREMENTS.md has the open question “requirements-open-0?”. The answer: First on the waitlist Remove its callout.",
        ])

        run(&spec)
        #expect(spec.changeRequests.isEmpty)
        #expect(spec.cards.map(\.answerText) == ["Yes", "First on the waitlist"])   // answered cards stay
        #expect(spec.nextStep == .draft(.architecture))
        run(&spec)
        run(&spec)
        #expect(spec.written == [.requirements, .architecture, .tasks])
        #expect(spec.nextStep == .check)
        #expect(!spec.isReady)
        run(&spec)
        #expect(spec.analyze == .passed)
        #expect(spec.nextStep == nil)
        #expect(spec.isReady)
        let started = spec.startBuilding()
        #expect(started)
        #expect(spec.stage == .done)
    }

    @Test func writeItNowTurnsOpenCardsIntoGuessesWithoutARun() {
        var spec = feature()
        spec.startBoard()
        run(&spec, asked: [question("requirements-a", .requirements), question("requirements-open-0", .requirements, round: .open)])
        spec.answer(card: "requirements-a", .option(0, note: nil))
        spec.writeNow()
        #expect(spec.openCards.isEmpty)
        #expect(spec.cards.map(\.answerText) == ["Yes", "Mel decided"])
        // The answer given goes in; the guess costs nothing.
        #expect(spec.changeRequests.count == 1)
        #expect(spec.nextStep == .change)

        var guessed = feature()
        guessed.startBoard()
        run(&guessed, asked: [question("requirements-a", .requirements)])
        guessed.writeNow()
        #expect(guessed.cards[0].answerText == "Mel guessed: No")   // the suggested option
        #expect(guessed.nextStep == .draft(.architecture))
    }

    @Test func changingAnAnswerLaterRunsAChange() {
        var spec = feature([question("pay", .requirements, round: .intake)])
        spec.answer(card: "pay", .option(0, note: nil))
        spec.startBoard()
        run(&spec, asked: [question("requirements-a", .requirements)])
        spec.answer(card: "requirements-a", .option(0, note: nil))
        run(&spec)
        run(&spec)
        run(&spec)
        run(&spec)
        #expect(spec.isReady)

        spec.reopen(card: "requirements-a")
        #expect(!spec.isReady)
        #expect(spec.nextStep == nil)
        spec.answer(card: "requirements-a", .text("Only on weekdays"))
        #expect(spec.nextStep == .change)
        spec.answer(card: "pay", .option(1, note: nil))   // an intake answer, after the files exist
        #expect(spec.changeRequests == [
            "The answer to “pay?” is now: No Change every file it affects.",
            "REQUIREMENTS.md asked “requirements-a?”. The answer: Only on weekdays",
        ])
        run(&spec)
        #expect(spec.isReady)
    }

    // MARK: Check

    @Test func checkIssuesAreCardsAndTheirAnswersAreFixes() {
        var spec = feature()
        spec.startBoard()
        run(&spec); run(&spec); run(&spec)
        var result = AnalyzeResult.coverage(requirements: "# Requirements\n\n## 1. Book\n\n- 1.1 THE APP SHALL book.\n", experience: nil, tasks: "# Tasks\n")
        result.issues.insert(contradiction, at: 0)
        run(&spec, check: result)

        #expect(spec.analyze == .issues(2))
        #expect(spec.cards.map(\.id) == ["issue-c1", "issue-task-1.1"])
        #expect(spec.cards.map(\.disagrees) == [true, false])
        #expect(spec.cards[0].options.map(\.label) == ["Use 24 Hours", "Use 12 Hours"])
        #expect(spec.cards.allSatisfy { $0.file == nil })
        #expect(spec.fileState(.tasks) == .ready)
        #expect(!spec.isReady)

        spec.answer(card: "issue-c1", .option(0, note: nil))
        #expect(spec.analyze == .issues(1))
        #expect(spec.nextStep == nil)
        spec.answer(card: "issue-task-1.1", .text("Fold it into the booking task."))
        #expect(spec.analyze == .passed)
        #expect(spec.changeRequests == ["Change criterion 1.3 to 24 hours.", "REQUIREMENTS 1.1: No task covers criterion 1.1. The user says: Fold it into the booking task."])
        #expect(spec.nextStep == .change)
        run(&spec)
        #expect(spec.nextStep == nil)   // no second check run on its own
        #expect(spec.isReady)
        #expect(spec.cards[0].answerText == "Use 24 Hours")

        // Mel's own checks again after the change: the task issue is gone, the contradiction card stays.
        spec.analysis?.refresh(requirements: "# Requirements\n\n## 1. Book\n\n- 1.1 THE APP SHALL book.\n", experience: nil, tasks: "# Tasks\n\n- [ ] 1. Book\n  - Covers: 1.1\n")
        #expect(spec.analysis?.issues.map(\.id) == ["c1"])
        #expect(spec.analysis?.issues[0].answer == .option(0, note: nil))
        #expect(spec.analysis?.stats.map(\.value) == ["1 of 1", "1"])
    }

    @Test func quickFixHasNoCheck() {
        var spec = Spec(name: "Fix", idea: "x", size: .quickFix, folder: URL(filePath: "/tmp/fix/specs/fix"))
        spec.startBoard()
        run(&spec)
        #expect(spec.nextStep == nil)
        #expect(spec.isReady)
    }

    @Test func unreadableCheckDoesNotBlockOrLoop() {
        var spec = feature()
        spec.startBoard()
        run(&spec); run(&spec); run(&spec)
        spec.begin(.check)
        spec.checkFailed()
        #expect(spec.analyze == .stale)
        #expect(spec.nextStep == nil)
        #expect(spec.isReady)
    }

    // MARK: Stops

    @Test func stoppedDraftKeepsItsFileAndResumeContinuesIt() {
        var spec = feature()
        spec.startBoard()
        run(&spec)
        spec.begin(.draft(.architecture))
        spec.halt(.usageLimit(resetsAt: nil), during: .draft(.architecture))
        #expect(spec.halted == Halt(reason: .usageLimit(resetsAt: nil), file: .architecture))
        #expect(spec.fileState(.architecture) == .needsYou)
        #expect(spec.fileState(.requirements) == .ready)   // finished files are untouched
        #expect(spec.nextStep == nil)

        var byHand = spec
        byHand.finishByHand()
        #expect(byHand.written == [.requirements, .architecture])
        #expect(byHand.nextStep == .draft(.tasks))

        spec.resume()
        #expect(spec.nextStep == .draft(.architecture))
    }

    @Test func stoppedCheckRunsAgainAndStoppedChangeKeepsItsRequests() {
        var spec = feature()
        spec.startBoard()
        run(&spec, asked: [question("requirements-a", .requirements)])
        spec.answer(card: "requirements-a", .option(0, note: nil))
        spec.begin(.change)
        spec.halt(.timeout, during: .change)
        #expect(spec.nextStep == nil)
        spec.resume()
        #expect(spec.nextStep == .change)
        run(&spec); run(&spec); run(&spec)
        spec.begin(.check)
        spec.halt(.user, during: .check)
        spec.resume()
        #expect(spec.nextStep == .check)
    }

    @Test func interruptedRunsStartAgainAfterARelaunch() {
        var spec = feature()
        spec.startBoard()
        spec.begin(.draft(.requirements))
        #expect(spec.nextStep == .draft(.requirements))   // quit mid-draft
        spec.drafted(.requirements, asked: [])
        run(&spec); run(&spec)
        spec.begin(.check)
        #expect(spec.nextStep == .check)
    }

    // MARK: Edits and unplaced changes

    @Test func anEditWaitsForUpdateOrKeep() {
        var spec = feature()
        spec.startBoard()
        run(&spec); run(&spec)
        let edited = spec.editedOnBoard(.requirements)
        #expect(edited)
        #expect(spec.builtOnEdit == [.architecture])
        #expect(spec.fileState(.requirements) == .needsYou)
        #expect(spec.fileState(.architecture) == .needsYou)
        #expect(spec.fileState(.tasks) == .waiting)
        #expect(spec.nextStep == nil)   // TASKS.md waits for Update or Keep
        let again = spec.editedOnBoard(.tasks)
        #expect(!again)
        spec.settleEdit()
        #expect(spec.builtOnEdit.isEmpty)
        #expect(spec.nextStep == .draft(.tasks))
    }

    @Test func anUnplacedChangeBlocksTheBoard() {
        var spec = feature()
        spec.startBoard()
        run(&spec)
        spec.unplacedChange = UnplacedChange(request: "Book offline.", change: Change(edits: []), files: [.requirements])
        #expect(spec.nextStep == nil)
        #expect(!spec.isReady)
        spec.unplacedChange = nil
        #expect(spec.nextStep == .draft(.architecture))
    }

    @Test func boardStateRoundTripsAndOlderStateDecodes() throws {
        var spec = feature()
        spec.startBoard()
        run(&spec, asked: [question("requirements-a", .requirements, about: "packs")])
        spec.answer(card: "requirements-a", .text("Yes"))
        spec.halt(.timeout, during: .change)
        spec.unplacedChange = UnplacedChange(request: "r", change: Change(edits: [.init(file: .tasks, old: "a", new: "b")]), files: [.tasks])
        let data = try JSONEncoder().encode(spec)
        #expect(try JSONDecoder().decode(Spec.self, from: data) == spec)

        // state.json from 0.4: none of the board's keys.
        var object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        for key in ["halted", "unplacedChange", "tokens", "build"] { object[key] = nil }
        object["stage"] = ["review": ["_0": "requirements"]]
        object["queue"] = ["tasks"]
        object["questions"] = [["id": "q", "title": "t", "why": "", "shapes": "requirements", "round": 2, "options": [[String: Any]]()] as [String: Any]]
        let old = try JSONDecoder().decode(Spec.self, from: JSONSerialization.data(withJSONObject: object))
        #expect(old.halted == nil)
        #expect(old.questions[0].about == nil)
        #expect(old.stage == .board)   // the lane stages open on the board
    }
}

struct ChangeTests {
    private let documents: [DocKind: String] = [
        .requirements: "# Requirements\n\n## 1. Book\n\n- 1.1 WHEN a member cancels 12 hours before, THE APP SHALL return the credit.\n",
        .tasks: "# Tasks\n\n- [ ] 1. Cancel\n  - Covers: 1.1\n- [ ] 2. Refund\n  - Covers: 1.1\n",
    ]

    @Test func appliesAcrossFilesAndSummarizes() throws {
        let change = try Change.decode(#"{"edits":[{"file":"requirements","old":"12 hours","new":"24 hours"},{"file":"TASKS.md","old":"1. Cancel","new":"1. Cancel in time"},{"file":"tasks","old":"2. Refund","new":"2. Return the credit"}]}"#)
        #expect(change.unplaced(in: documents).isEmpty)
        let result = try #require(change.apply(to: documents))
        #expect(result[.requirements]?.contains("24 hours before") == true)
        #expect(result[.tasks] == "# Tasks\n\n- [ ] 1. Cancel in time\n  - Covers: 1.1\n- [ ] 2. Return the credit\n  - Covers: 1.1\n")
        #expect(change.files(in: [.requirements, .architecture, .tasks]) == [.requirements, .tasks])
        #expect(change.summary(order: [.requirements, .architecture, .tasks]) == "Changed 1 place in REQUIREMENTS.md, 2 in TASKS.md")
        #expect(Change(edits: []).summary(order: [.requirements]) == "Nothing needed to change")
        #expect(Change(edits: []).apply(to: documents) == [:])
    }

    @Test func oneUnplacedEditAppliesNothing() {
        let change = Change(edits: [.init(file: .requirements, old: "12 hours", new: "24 hours"), .init(file: .tasks, old: "  - Covers: 1.1\n", new: ""), .init(file: .architecture, old: "x", new: "y")])
        #expect(change.apply(to: documents) == nil)
        #expect(change.unplaced(in: documents) == [.architecture, .tasks])   // repeated in TASKS.md; ARCHITECTURE.md isn't written
        // "Rewrite FILE" takes those files; the rest still applies.
        #expect(change.without([.architecture, .tasks]).apply(to: documents)?.keys.map(\.self) == [.requirements])
    }

    /// A real reply (Kingdom and Dynasty, 0.8): the edits, then a questions block the prompt didn't ask for.
    @Test func textAfterTheJSONIsIgnored() throws {
        let reply = #"""
        {"edits": [{"file": "requirements", "old": "12 hours", "new": "24 hours {see D-19}"}]}

        <!-- mel:questions
        [{"id":"q1","title":"Foreign keys?","options":[{"label":"No","suggested":true}]}]
        -->
        """#
        let change = try Change.decode(reply)
        #expect(change.edits.map(\.new) == ["24 hours {see D-19}"])
    }

    @Test func unknownFileOrProseDoesNotDecode() {
        #expect(throws: (any Error).self) { try Change.decode(#"{"edits":[{"file":"readme","old":"a","new":"b"}]}"#) }
        #expect(throws: (any Error).self) { try Change.decode("Done.") }
    }
}

struct StoryTests {
    private let requirements = """
    # Requirements

    ## 1. Book a class

    P1 · MVP
    Source: your idea

    As a member, I want to book a class, so that I have a spot.

    - 1.1 WHEN a member taps Book, THE APP SHALL reserve a spot.

    ## 2. Buy a pack

    P1 · MVP

    As a member, I want to buy a class pack, so that I can book without paying each time.

    - 2.1 WHEN a member completes payment, THE APP SHALL add the pack's credits.
    - 2.2 THE APP SHALL email a receipt.

    <!-- MVP line -->

    ## 3. Gift cards

    P2

    As a member, I want to buy a gift card, so that I can give classes to a friend.

    - 3.1 WHEN a member completes payment, THE APP SHALL email the gift card.

    ## Quality requirements

    - Q1 THE APP SHALL open the schedule in under 1 second.

    """

    @Test func storiesParse() {
        let stories = Story.parse(requirements)
        #expect(stories.map(\.id) == ["1", "2", "3"])
        #expect(stories.map(\.title) == ["Book a class", "Buy a pack", "Gift cards"])
        #expect(stories.map(\.isFirst) == [true, true, false])
        #expect(stories.map(\.priority) == ["P1", "P1", "P2"])
        #expect(stories[1].criteria == ["2.1", "2.2"])
        #expect(stories[0].line == "As a member, I want to book a class, so that I have a spot.")
        #expect(Story.parse("# Requirements\n\n## 1. Fix\n\n- 1.1 THE APP SHALL not crash.\n").map(\.isFirst) == [true])
    }

    @Test func moveToLaterRetagsAndCrossesTheMVPLine() throws {
        let moved = try #require(Story.move("1", toLater: true, in: requirements))
        #expect(Story.parse(moved).map(\.id) == ["2", "1", "3"])
        #expect(Story.parse(moved).map(\.isFirst) == [true, false, false])
        #expect(moved.contains("email a receipt.\n\n<!-- MVP line -->\n\n## 1. Book a class\n\nP2\nSource: your idea\n"))
        #expect(moved.contains("reserve a spot.\n\n## 3. Gift cards\n"))
        #expect(!moved.contains("\n\n\n"))
        #expect(moved.hasSuffix("under 1 second.\n"))
        // Only that story changed.
        #expect(moved.count == requirements.count - "P1 · MVP".count + "P2".count)
    }

    @Test func moveToFirstAndBackIsTheSameFile() throws {
        let first = try #require(Story.move("3", toLater: false, in: requirements))
        #expect(Story.parse(first).map(\.isFirst) == [true, true, true])
        #expect(first.contains("- 3.1 WHEN a member completes payment, THE APP SHALL email the gift card.\n\n<!-- MVP line -->\n\n## Quality requirements"))
        #expect(first.contains("\n## 3. Gift cards\n\nP1 · MVP\n"))
        #expect(Story.move("3", toLater: true, in: first) == requirements)
        // The last MVP story moved to Later and back.
        let later = try #require(Story.move("2", toLater: true, in: requirements))
        #expect(later.contains("reserve a spot.\n\n<!-- MVP line -->\n\n## 2. Buy a pack\n\nP2\n"))
        #expect(Story.move("2", toLater: false, in: later) == requirements)
    }

    @Test func untaggedStoryGetsATagAndUnknownStoryIsNil() throws {
        let plain = "# Requirements\n\n## 1. Fix\n\nAs a user, I want no crash.\n\n- 1.1 THE APP SHALL not crash.\n"
        let moved = try #require(Story.move("1", toLater: true, in: plain))
        #expect(moved == "# Requirements\n\n## 1. Fix\n\nP2\n\nAs a user, I want no crash.\n\n- 1.1 THE APP SHALL not crash.\n")
        #expect(Story.move("7", toLater: true, in: requirements) == nil)
    }
}
