import SwiftUI
import MelSpec

/// Fixtures for `#Preview`s and `-screen`: one yoga studio spec in every state of the board.
enum PreviewData {
    static let project = Project(folder: FileManager.default.homeDirectoryForCurrentUser.appending(path: "Developer/yoga-studio-booking"), hasContext: true)
    static let folder = project.folder.appending(path: "specs/yoga-studio-booking")
    static let executable = FileManager.default.homeDirectoryForCurrentUser.appending(path: ".local/bin/claude")
    static let ready = AgentStatus.ready(executable: executable, version: "2.1.4")
    static let notSignedIn = AgentStatus.notSignedIn(executable: executable)

    static let idea = "Small yoga studios take bookings by text message. Members should book and cancel classes themselves, and teachers should see who is coming."

    static let questions: [Question] = [
        Question(
            id: "q1", title: "Who books the classes?", why: "Decides who the main user is.", shapes: .product,
            options: [
                Option(label: "Members book themselves", note: "Simplest for the studio.", suggested: true),
                Option(label: "Front desk books for them", note: "More control, more work."),
            ],
            answer: .option(0, note: nil)
        ),
        Question(
            id: "q2", title: "Do members pay when they book?", why: "Payments add a lot of scope.", shapes: .product,
            options: [
                Option(label: "No, they pay at the studio", note: "Keeps the first version small.", suggested: true),
                Option(label: "Yes, card at booking", note: "Needs a payment provider."),
            ],
            answer: .agentDecides
        ),
        Question(
            id: "q3", title: "How many classes run at the same time?", why: "Affects how the schedule is shown.", shapes: .requirements,
            options: [
                Option(label: "One room", note: "One class at a time."),
                Option(label: "Several rooms", note: "Classes can overlap.", suggested: true),
            ],
            answer: .option(1, note: "Two rooms for now")
        ),
        Question(
            id: "q3a", title: "What do teachers need to see before class?", why: "Shapes the teacher view.", shapes: .architecture,
            options: [], answer: .text("Who is booked, and who is new to the studio.")
        ),
        Question(
            id: "q3b", title: "Anything the studio already uses that this must work with?", why: "Existing tools limit the design.", shapes: .architecture,
            options: [], answer: .agentDecides
        ),
        Question(
            id: "q4", title: "Until when can members cancel?", why: "Late cancellations leave empty spots that others could have booked.", shapes: .requirements,
            options: [
                Option(label: "Any time before class", note: "Friendly, but spots can go unused."),
                Option(label: "Up to 12 hours before", note: "Common for small studios.", suggested: true),
                Option(label: "Up to 24 hours before", note: "Strict; fewer empty spots."),
            ]
        ),
    ]

    static let coverage: [CoverageItem] = [
        CoverageItem(label: "Who uses it", phase: .product, state: .covered),
        CoverageItem(label: "Payments", phase: .product, state: .covered),
        CoverageItem(label: "Schedule", phase: .requirements, state: .covered),
        CoverageItem(label: "Cancellations", phase: .requirements, state: .asking),
        CoverageItem(label: "Waiting list", phase: .requirements, state: .notYet),
        CoverageItem(label: "Teacher view", phase: .architecture, state: .notYet),
        CoverageItem(label: "Notifications", phase: .architecture, state: .notYet),
        CoverageItem(label: "Build order", phase: .tasks, state: .notYet),
    ]

    static let allAnswered: [Question] = questions.map { question in
        var question = question
        question.answer = question.answer ?? (question.options.isEmpty ? .text("Friendly and short.") : .option(1, note: nil))
        return question
    }

    static func spec(_ stage: Stage, _ docs: [DocKind: DocStatus], questions: [Question] = allAnswered, analyze: AnalyzeStatus = .locked) -> Spec {
        Spec(name: "Yoga Studio Booking", idea: idea, folder: folder, stage: stage, docs: docs, questions: questions, coverage: coverage, analyze: analyze)
    }

    /// Product-size statuses in file order, missing kinds locked.
    static func docs(_ statuses: DocStatus...) -> [DocKind: DocStatus] {
        var docs = SpecSize.product.allLocked
        for (kind, status) in zip(SpecSize.product.files, statuses) { docs[kind] = status }
        return docs
    }

    static let locked = SpecSize.product.allLocked

    static let discovery = spec(.discovery, locked, questions: questions)
    /// The check's result as drawn on the old Analyze screen; the board takes its issues as cards.
    static let analysis = AnalyzeResult(
        stats: [
            .init(value: "14 of 15", label: "requirements have a task"), .init(value: "7 of 7", label: "screens trace to a requirement"),
            .init(value: "2 of 3", label: "quality requirements are covered"), .init(value: "1", label: "contradiction between files"),
        ],
        issues: [
            .init(id: "i1", kind: .contradiction, location: "REQUIREMENTS 1.3 · EXPERIENCE › Confirm booking",
                  text: "Requirement 1.3 returns the credit up to 12 hours before class, but the screen copy says “Free cancellation up to 24 hours”.",
                  actions: [.init(label: "Use 24 Hours", fix: "", files: [.requirements]), .init(label: "Use 12 Hours", fix: "", files: [.experience])]),
            .init(id: "i2", kind: .noTask, location: "REQUIREMENTS 2.2",
                  text: "When the studio cancels a class, members get their credit back. No task builds this and no test checks it.",
                  actions: [.init(label: "Move to Later", fix: "", files: [.requirements]), .init(label: "Add Task", fix: "", files: [.tasks])]),
            .init(id: "i3", kind: .qualityNotCovered, location: "REQUIREMENTS Q3",
                  text: "The schedule should be readable offline. ARCHITECTURE.md has no local cache and TASKS.md has no task for it.",
                  actions: [.init(label: "Drop Requirement", fix: "", files: [.requirements]), .init(label: "Add Task", fix: "", files: [.architecture, .tasks])]),
            .init(id: "i4", kind: .scopeCreep, location: "TASKS 9", text: "Task 9 “Notification settings screen” traces to no requirement.",
                  actions: [.init(label: "Remove Task", fix: "", files: [.tasks]), .init(label: "Link to Requirement", fix: "", files: [.tasks])]),
        ],
        coverage: [
            ("1.1", "Book a class with free spots", ["c", "c", "c", "c"]), ("1.2", "Join the waitlist when full", ["c", "c", "c", "c"]),
            ("1.3", "Cancel 12h before, credit returned", ["x", "c", "c", "c"]), ("2.1", "Pay, get credits and a receipt", ["c", "c", "c", "c"]),
            ("2.2", "Studio cancels, credit returned", ["c", "c", "m", "m"]), ("Q1", "Schedule opens in under 1 second", ["c", "c", "c", "c"]),
            ("Q2", "Payment data never stored on device", ["c", "c", "c", "c"]), ("Q3", "Schedule readable offline", ["c", "m", "m", "m"]),
        ].map { id, text, m in
            let mark = { (s: String) -> AnalyzeResult.Mark in s == "c" ? .covered : s == "m" ? .missing : .conflict }
            return AnalyzeResult.CoverageRow(id: id, text: text, screen: mark(m[0]), architecture: mark(m[1]), task: mark(m[2]), test: mark(m[3]))
        }
    )
    static var tokens: Spec {
        var spec = done
        spec.tokens = [.questions: 2_140, .product: 5_300, .requirements: 11_800, .experience: 7_950, .architecture: 8_400, .tasks: 6_200, .checks: 3_100, .changes: 1_820]
        return spec
    }

    static let done = spec(.done, docs(.approved, .approved, .approved, .approved, .approved), analyze: .passed)

    /// The other rows of the drawn sidebar: one spec being built, one done.
    static let others: [Spec] = [("Filter schedule by teacher", SpecSize.feature, BuildState.building), ("Double booking on fast taps", .quickFix, .done)].map { name, size, build in
        var spec = Spec(name: name, idea: "", size: size, folder: project.folder.appending(path: "specs/\(name.lowercased().replacing(" ", with: "-"))"), stage: .done,
                        docs: Dictionary(uniqueKeysWithValues: size.files.map { ($0, DocStatus.approved) }))
        spec.build = build
        return spec
    }
    static let library = [board] + others
    static let featureIdea = "Members can filter the weekly schedule by teacher and see a short teacher profile on each class."

    /// Past Start: previews of the main window open on the library.
    static var startedDefaults: UserDefaults {
        let defaults = UserDefaults(suiteName: "preview-started")!
        defaults.set(true, forKey: "didShowWelcome")
        return defaults
    }

    static let requirementsBlocks: [Block] = [
        .heading(level: 1, text: "Requirements"),
        .paragraph("5 stories, 14 acceptance criteria."),
        .heading(level: 2, text: "Story 1: Book a class"),
        .paragraph("As a member, I want to book a class from the schedule, so that I have a spot."),
        .criterion(id: "1.1", text: "WHEN a member taps Book on a class with free spots, THE system SHALL reserve one spot for that member."),
        .criterion(id: "1.2", text: "IF the class is full, THEN THE system SHALL show \"Full\" and offer the waiting list."),
        .assumption(index: 0, text: "Members can cancel up to 12 hours before class."),
        .heading(level: 2, text: "Story 2: Cancel a booking"),
        .paragraph("As a member, I want to cancel a booking, so that someone else can take my spot."),
        .criterion(id: "2.1", text: "WHILE more than 12 hours remain before class, THE system SHALL let the member cancel."),
        .listItem("Cancelled spots go to the first person on the waiting list."),
        .heading(level: 2, text: "Tasks"),
        .task(id: "T1", text: "Schedule screen with Book buttons", done: false, covers: ["1.1", "1.2"]),
        .task(id: "T2", text: "Cancel flow", done: true, covers: ["2.1"]),
        .code("POST /bookings { classID, memberID }"),
    ]

    static func updates(canCheck: Bool = true, automaticallyChecks: Bool = true) -> UpdateSettings {
        UpdateSettings(version: "0.2 (build 123)", canCheck: canCheck, automaticallyChecks: .constant(automaticallyChecks), check: {})
    }

    static let repositories = [("yoga-studio-booking", "Kotlin", 0), ("habit-tracker", "Kotlin", 14), ("portfolio-site", "TypeScript", 100)].map { name, language, days in
        FoundRepository(
            url: FileManager.default.homeDirectoryForCurrentUser.appending(path: "Developer/\(name)", directoryHint: .isDirectory),
            language: language,
            modified: Date.now.addingTimeInterval(-Double(days) * 86_400)
        )
    }

    static let context = ProjectContext(
        product: "# Product\n\nMembers book yoga classes. Sign-in and schedule are live; do not change their behavior.",
        tech: "# Tech\n\nKotlin Multiplatform, Compose Multiplatform, Ktor, SQLDelight, Koin.",
        structure: "# Structure\n\nFeature-first packages under shared/feature/<name>. One ViewModel per screen.\n\n## Modules\n\n- Sign-in — feature/auth\n- Schedule — feature/schedule\n- Class detail — feature/schedule/detail",
        principles: "# Principles\n\n- Reuse existing modules before adding new ones. Name the module you extend.\n- No new dependency without a short reason in ARCHITECTURE.md.\n- Every check in the plan gets a test before a task counts as done.",
        read: [
            ReadItem(label: "README and docs folder", source: "README.md, docs/"),
            ReadItem(label: "Build files and dependencies", source: "build.gradle.kts"),
            ReadItem(label: "3 modules: shared, androidApp, iosApp", source: "settings.gradle.kts"),
            ReadItem(label: "2 features already built: sign-in, schedule", source: "shared/feature/"),
        ],
        sources: ["product.md": "From README", "tech.md": "Detected", "structure.md": "Detected"]
    )

    static func appState(_ specs: [Spec] = [discovery], agent: AgentStatus = ready, projects: [Project] = [project], contexts: [Project.ID: ProjectContext] = [:], foundRepositories: [FoundRepository] = [], readingContext: Set<Project.ID> = [], branches: [Project.ID: String] = [:], sessions: [SpecSession] = [], missing: [URL] = [], github: GitHubAccount = .signedOut, githubRepos: [GitHubRepo] = [], remotes: [Project.ID: String] = [:]) -> AppState {
        let state = AppState.preview(specs, agent: agent, projects: projects, contexts: contexts, foundRepositories: foundRepositories, readingContext: readingContext, branches: branches, sessions: sessions, github: github, githubRepos: githubRepos, remotes: remotes)
        state.missingFolders = missing
        return state
    }

    /// GH-1, GH-2: the account's repos, newest first; habit-tracker and kingdom-and-dynasty aren't on this Mac.
    static let githubRepos = [("habit-tracker", "Kotlin", false, 3), ("yoga-studio-booking", "Kotlin", false, 0), ("kingdom-and-dynasty", nil, true, 1), ("portfolio-site", "TypeScript", false, 40)]
        .map { name, language, isEmpty, days in
            GitHubRepo(nameWithOwner: "kaanf/\(name)", isPrivate: name != "portfolio-site", isEmpty: isEmpty, language: language,
                       updatedAt: Date.now.addingTimeInterval(-Double(days) * 86_400), url: URL(string: "https://github.com/kaanf/\(name)")!)
        }
    static let remotes = [project.id: "kaanf/yoga-studio-booking"]

    static let habitTracker = Project(folder: FileManager.default.homeDirectoryForCurrentUser.appending(path: "Developer/habit-tracker"))
    // REQUIREMENTS.md with an assumption and an open question.
    static let reviewMarkdown = """
        # Requirements

        ## 1. Book a class

        P1 · MVP

        As a member, I want to book a class from the weekly schedule, so that my spot is guaranteed.

        Source: your idea, Question 4 (cancellations)

        - 1.1 WHEN a member books a class with free spots, THEN one spot is reserved, one credit is deducted and the class shows under Upcoming.
        - 1.2 WHEN a class is full, THEN the app offers to join the waitlist instead.

        > [!ASSUMPTION]
        > The waitlist is first come, first served. When a spot frees up, the first member on it is booked automatically and notified.

        ## 2. Buy a class pack

        P1 · MVP

        As a member, I want to buy a pack of classes in the app, so that I can book without paying each time.

        Source: Question 2 (payments)

        - 2.1 WHEN a member completes payment, THEN the pack’s credits are added and a receipt is emailed.

        > [!OPEN QUESTION]
        > What happens to unused credits when a pack expires?

        <!-- MVP line -->

        ## Quality requirements

        Source: Intake (privacy, speed, offline) and project principles

        - Q1 WHEN a member opens the weekly schedule on a mid-range phone, THEN it appears in under 1 second.
        - Q2 WHEN a member pays, THEN no card data is stored on the device.
        - Q3 WHEN the phone is offline, THEN the schedule shows the last loaded classes and when they were updated.

        ## Edge cases

        - Two members book the last spot at the same moment: one gets it, the other is offered the waitlist.
        - Payment succeeds but the app closes before credits show: credits appear on next open.
        """
    // MARK: Board (V2)

    private static let boardDocuments: [DocKind: String] = [.product: "# Product\n\nA booking app for one yoga studio.\n", .requirements: reviewMarkdown, .experience: experienceMarkdown, .architecture: "# Architecture\n\n## Modules\n\n- shared/booking: booking rules, credits, waitlist.\n", .tasks: tasksMarkdown]
    private static let boardDecisions = [
        Decision(id: "D-02", title: "Which phones first?", reason: "iOS and Android", source: "Your answer", date: .now, replaces: nil, affects: []),
        Decision(id: "D-01", title: "How do members pay?", reason: "Class packs bought in the app", source: "Intake Q1", date: .now, replaces: nil, affects: []),
    ]
    private static let boardCards: [Question] = allAnswered + [
        Question(id: "requirements-studio", title: "If the studio cancels a class, what happens to members’ credits?", why: "", shapes: .requirements, round: .draft,
                 options: [Option(label: "Give them back", note: ""), Option(label: "Give back and notify", note: "", suggested: true)], about: "cancelling"),
        Question(id: "requirements-waitlist", title: "When a spot frees up, who gets it?", why: "", shapes: .requirements, round: .draft,
                 options: [Option(label: "First on the waitlist", note: "", suggested: true), Option(label: "Teacher picks", note: "")], about: "full classes"),
    ]

    /// V2-2 with everything written: one contradiction card, one answered card.
    static let board: Spec = {
        var spec = PreviewData.spec(.board, docs(.approved, .approved, .approved, .approved, .approved), questions: boardCards, analyze: .issues(1))
        spec.questions[spec.questions.count - 1].answer = .option(0, note: nil)
        spec.questions[spec.questions.count - 2].answer = .option(1, note: nil)
        var result = analysis
        result.issues = [AnalyzeResult.Issue(id: "c1", kind: .contradiction, location: "REQUIREMENTS.md · your answer and old-schedule.jpg", text: "You said members can cancel up to 12 hours before class. The schedule photo you added says 24 hours. Which one?", actions: [
            .init(label: "12 hours", fix: "Use 12 hours.", files: [.requirements]), .init(label: "24 hours", fix: "Use 24 hours.", files: [.requirements]),
        ])]
        spec.analysis = result
        spec.tokens = tokens.tokens
        return spec
    }()
    static let boardSession = SpecSession.preview(board, documents: boardDocuments, decisions: boardDecisions)
    /// A TASKS.md from before phases: Roadmap groups it by priority.
    static let boardFlatTasksSession = SpecSession.preview(board, documents: boardDocuments.merging([.tasks: tasksMarkdown.split(separator: "\n", omittingEmptySubsequences: false).filter { !$0.hasPrefix("## ") }.joined(separator: "\n")]) { $1 }, decisions: boardDecisions)

    /// V2-9: REQUIREMENTS.md is written; EXPERIENCE.md waits for two answers.
    static let boardWaiting: Spec = {
        var spec = PreviewData.spec(.board, docs(.approved, .approved), questions: boardCards)
        spec.tokens = [.questions: 2_100, .product: 4_800, .requirements: 7_400]
        return spec
    }()
    static let boardWaitingSession = SpecSession.preview(boardWaiting, documents: boardDocuments.filter { $0.key == .product || $0.key == .requirements }, decisions: boardDecisions)

    /// EXPERIENCE.md being written: the working line under the toolbar, the pulsing file dot.
    static let boardWritingSession: SpecSession = {
        var spec = PreviewData.spec(.board, docs(.approved, .approved, .writing), questions: boardCards.map { var q = $0; q.answer = q.answer ?? .option(0, note: nil); return q })
        spec.tokens = [.questions: 2_100, .product: 4_800, .requirements: 7_400]
        return SpecSession.preview(spec, documents: boardDocuments.filter { $0.key == .product || $0.key == .requirements },
                                   liveText: "# Experience\n\n## Flow 1 · Book a class\n\nCovers: 1.1\n\n1. Schedule (1.1)\n", isRunning: true, decisions: boardDecisions)
    }()

    /// The intake: one question at a time.
    static let boardAsking: Spec = {
        var spec = PreviewData.spec(.discovery, locked, questions: Array(allAnswered.prefix(3)))
        spec.questions[1].answer = nil
        spec.questions[2].answer = nil
        return spec
    }()
    static let boardAskingSession = SpecSession.preview(boardAsking)

    /// V2-5: stopped while writing ARCHITECTURE.md.
    static let boardStopped: Spec = {
        var spec = PreviewData.spec(.board, docs(.approved, .approved, .approved, .stopped))
        spec.halted = Halt(reason: .usageLimit(resetsAt: nil), file: .architecture)
        return spec
    }()
    static let boardStoppedSession = SpecSession.preview(boardStopped, documents: boardDocuments.filter { $0.key != .tasks }, decisions: boardDecisions)

    /// V2-7: a Tell Mel change couldn't be placed.
    static let boardUnplaced: Spec = {
        var spec = PreviewData.spec(.board, docs(.approved, .approved, .approved, .approved, .approved), analyze: .passed)
        spec.unplacedChange = UnplacedChange(request: "Members can book while offline, and the bookings sync when they’re back online.", change: Change(edits: []), files: [.architecture])
        spec.tokens = tokens.tokens
        return spec
    }()
    static let boardUnplacedSession = SpecSession.preview(boardUnplaced, documents: boardDocuments, decisions: boardDecisions)

    /// V2-4: a Tell Mel change was just applied.
    static let boardChangedSession: SpecSession = {
        var spec = PreviewData.spec(.board, docs(.approved, .approved, .approved, .approved, .approved), analyze: .passed)
        spec.tokens = tokens.tokens
        let passage = "WHEN a class is full, THE APP SHALL offer to join the waitlist instead."
        return SpecSession.preview(spec, documents: boardDocuments, decisions: boardDecisions,
                                   lastChange: SpecSession.ChangeResult(line: "Changed 2 places in REQUIREMENTS.md, 1 in ARCHITECTURE.md", tokens: 1_800, passages: [.requirements: [passage]]))
    }()

    /// V2-24: the panel with a request written.
    static let tellComposeSession = SpecSession.preview(boardChangedSession.spec, documents: boardDocuments, decisions: boardDecisions,
                                                        tellDraft: "Let teachers cancel a class from the app. Members get a push notification and their credit back.")
    /// V2-25: Mel placing it; the reply has named two files so far.
    static let tellWorkingSession = SpecSession.preview(boardChangedSession.spec, documents: boardDocuments, isRunning: true, decisions: boardDecisions,
                                                        telling: "Let teachers cancel a class from the app. Members get a push notification and their credit back.", tellFound: [.requirements, .architecture])
    /// V2-26: three changes in two files, already applied; the second undone.
    static let tellReviewSession: SpecSession = {
        var change = SpecSession.ChangeResult(line: "Changed 2 places in REQUIREMENTS.md, 1 in ARCHITECTURE.md", tokens: 1_800, passages: [:])
        change.request = "Let teachers cancel a class from the app. Members get a push notification and their credit back."
        change.edits = [
            Change.Edit(file: .requirements, old: "- 1.2 WHEN a class is full, THE APP SHALL offer to join the waitlist.", new: "- 1.2 WHEN a class is full, THE APP SHALL offer to join the waitlist instead."),
            Change.Edit(file: .requirements, old: "", new: "- 1.4 WHEN a teacher cancels a class, THE APP SHALL return every booked member's credit and send a push notification."),
            Change.Edit(file: .architecture, old: "Push is used for class reminders only.", new: "Push is used for class reminders and for class cancellations."),
        ]
        change.sections = ["1. Book a class", "1. Book a class", "Notifications"]
        change.reverted = [1]
        return SpecSession.preview(boardChangedSession.spec, documents: boardDocuments, decisions: boardDecisions, lastChange: change)
    }()

    /// The edit banner: REQUIREMENTS.md was changed by hand.
    static let boardEditedSession = SpecSession.preview(spec(.board, docs(.approved, .edited, .stale, .stale, .stale), analyze: .passed), documents: boardDocuments, decisions: boardDecisions)

    // EXPERIENCE.md as drawn.
    static let experienceMarkdown = """
        # Experience

        ## Flow 1 · Book a class

        Covers: 1.1, 1.2, 1.3

        1. Schedule (1.1)
        2. Class detail (1.1, 1.2)
        3. Confirm booking (1.1)
        4. Booked (1.1, 1.3)

        - Class is full: Waitlist sheet (1.2)
        - No credits left: Buy pack (2.1)

        ## Screens and states

        Every screen lists what it shows when data is missing, slow, failing or offline.

        | Screen | States | Criteria |
        |---|---|---|
        | Schedule | Default, Empty week, Loading, Offline, Error | 1.1 |
        | Class detail | Default, Full, Loading, !Error | 1.1, 1.2 |
        | Confirm booking | Default, No credits, !Error | 1.1 |
        | Booked | Default, Added to calendar | 1.1 |
        | Waitlist sheet | Default, Spot opened, Error | 1.2 |
        | Upcoming | Default, Empty, Cancel confirm, Late cancel | 1.3 |
        | Buy pack | Default, Paying, Paid, Card declined | 2.1 |

        ## Visual direction

        > [!ASSUMPTION]
        > Calm and light, one accent taken from the studio logo, large tap targets for use right before class. Platform-native controls on iOS and Android.
        """
    // TASKS.md as drawn on Build (V2-3).
    static let tasksMarkdown = """
        # Tasks

        ## 1 · Foundation

        - [ ] 1. Booking data and local store
          - Priority: P1
          - Covers: 1.1, 1.2
          - Reads: REQUIREMENTS.md 1.1 and 1.2, ARCHITECTURE.md › Data, D-05
          - Verify: `./gradlew :shared:allTests --tests "*Booking*"`
          - Changes: shared/booking

        ## 2 · Booking and paying

        - [ ] 2. Schedule and class screens
          - Priority: P1
          - Covers: 1.1
          - Reads: EXPERIENCE.md › Flow 1, ARCHITECTURE.md › Modules
          - Verify: `./gradlew :androidApp:connectedCheck`
          - Changes: androidApp, iosApp
          - Parallel with: 3
        - [ ] 3. Class pack checkout
          - Priority: P1
          - Covers: 2.1
          - Reads: REQUIREMENTS.md 2.1, EXPERIENCE.md › Flow 2, D-03
          - Verify: `./gradlew :shared:allTests --tests "*Checkout*"`
          - Changes: shared/payments
          - Parallel with: 2

        ## 3 · Cancelling and the waitlist

        - [ ] 4. Cancel a booking
          - Priority: P1
          - Covers: 1.3
          - Reads: REQUIREMENTS.md 1.3, D-04
          - Verify: `./gradlew :shared:allTests --tests "*Cancel*"`
          - Changes: shared/booking
          - Parallel with: 5
        - [ ] 5. Waitlist
          - Priority: P1
          - Covers: 1.2
          - Reads: REQUIREMENTS.md 1.2, EXPERIENCE.md › Class detail
          - Verify: `./gradlew :shared:allTests --tests "*Waitlist*"`
          - Changes: shared/booking
          - Parallel with: 4
        """
    static let doneSession = SpecSession.preview(tokens, documents: boardDocuments)

    /// V2-3 midway, as drawn: task 1 done, 2 running, 3 failed, 4 and 5 waiting.
    static let buildingSession: SpecSession = {
        var spec = tokens
        spec.build = .building
        spec.taskCount = 5
        spec.runs = [1: TaskRun(state: .done, at: Calendar.current.date(bySettingHour: 14, minute: 2, second: 0, of: .now)),
                     2: TaskRun(state: .running),
                     3: TaskRun(state: .failed, output: "CheckoutTest > receipt is emailed after payment FAILED\nCheckoutTest > credits added once on retry FAILED")]
        return SpecSession.preview(spec, documents: boardDocuments)
    }()
    /// V2-12: Mel is changing the files for a request from task 3.
    static let buildTellingSession = SpecSession.preview(buildingSession.spec, documents: boardDocuments, isRunning: true, tellingTask: 3)
    /// V2-13: the change touched tasks 1–3 and added task 6 to step 2.
    static let buildChangedSession: SpecSession = {
        var spec = buildingSession.spec
        for number in 1...3 { spec.runs?[number]?.prompt = "the prompt before the change" }
        var documents = boardDocuments
        documents[.tasks] = tasksMarkdown.replacingOccurrences(of: "- [ ] 4. Cancel a booking", with: """
            - [ ] 6. Receipt email
              - Priority: P1
              - Covers: 2.2
              - Reads: REQUIREMENTS.md 2.2, D-07
              - Verify: `./gradlew :shared:allTests --tests "*Receipt*"`
              - Changes: shared/notifications
              - Parallel with: 2, 3
            - [ ] 4. Cancel a booking
            """)
        var change = SpecSession.ChangeResult(line: "Changed REQUIREMENTS.md, EXPERIENCE.md, TASKS.md", tokens: 2_100, passages: [:])
        change.newTasks = [6]
        change.updatedTasks = [1, 2, 3]
        return SpecSession.preview(spec, documents: documents, lastChange: change)
    }()
    /// V2-14: the request doesn't fit ARCHITECTURE.md.
    static let buildUnplacedSession: SpecSession = {
        var spec = buildingSession.spec
        spec.unplacedChange = UnplacedChange(request: "Receipts should come from the payment provider’s own emails, not from our server.", change: Change(edits: []), files: [.architecture])
        return SpecSession.preview(spec, documents: boardDocuments)
    }()
    // V2-17 to V2-21: tasks run in Mel.
    static let buildReport = BuildReport(
        works: ["A member can book a class with free spots for one credit.", "Bookings are kept on the phone and are still there after a restart."],
        decisions: [.init(title: "Each booking gets a random ID", why: "Two phones booking at the same moment never clash, even offline.", instead: "numbers handed out by the server; simpler to read, but booking would need a connection."),
                    .init(title: "A booking keeps the class time it was made for", why: "If the studio moves a class, members see the old time until they open the app online.", instead: "always look up the time; needs a connection to show a booking.")],
        notDone: ["The “Full” label on a class waits for task 5 (Waitlist)."],
        refused: ["Bash: mkdir -p build/tmp"])
    /// V2-17: task 1 done in Mel with its report, task 2 running in Mel.
    static let buildRunSession: SpecSession = {
        var spec = tokens
        spec.build = .building
        spec.taskCount = 5
        spec.runs = [1: TaskRun(state: .done, at: Calendar.current.date(bySettingHour: 14, minute: 2, second: 0, of: .now)), 2: TaskRun(state: .running)]
        spec.runs?[1]?.report = buildReport
        spec.runs?[1]?.tokens = 21_400
        spec.runs?[2]?.tokens = 18_000
        let steps = ["read specs/yoga-studio-booking/EXPERIENCE.md", "search Schedule", "write schedule/ScheduleScreen.kt", "write schedule/ScheduleViewModel.kt", "edit androidApp/AppNavigation.kt", "write Schedule/ScheduleView.swift", "run ./gradlew :androidApp:connectedCheck"]
        return SpecSession.preview(spec, documents: boardDocuments, activity: steps.map { ActivityLine(at: .now, text: $0) }, isRunning: true, runningTask: 2)
    }()
    /// V2-19: task 1's report open (BuildView opens it in the preview).
    static let buildReportSession: SpecSession = {
        var spec = buildRunSession.spec
        spec.runs?[2] = nil
        return SpecSession.preview(spec, documents: boardDocuments)
    }()
    /// A task run in Mel whose check failed: Let Claude Code fix it goes on in its session (OQ #42).
    static let buildFailedInMelSession: SpecSession = {
        var spec = buildReportSession.spec
        spec.runs?[2] = TaskRun(state: .failed, output: "ScheduleTest > shows today's classes FAILED")
        spec.runs?[2]?.session = "build-2"
        return SpecSession.preview(spec, documents: boardDocuments)
    }()
    /// V2-21: task 2 stopped in Mel.
    static let buildStoppedSession: SpecSession = {
        var spec = buildReportSession.spec
        spec.runs?[2] = TaskRun(state: .stopped)
        return SpecSession.preview(spec, documents: boardDocuments)
    }()
    /// Task 2's run in Mel ended with its report but no commit: the plan didn't fit.
    static let buildNoCommitSession: SpecSession = {
        var spec = buildReportSession.spec
        spec.runs?[2] = TaskRun(state: .running)
        spec.runs?[2]?.report = BuildReport(works: [], notDone: ["The booking screen wasn’t started: the shared/booking module doesn’t exist yet and the task may only change androidApp."],
                                             refused: ["Creating shared/booking/build.gradle.kts, outside the task’s folders."])
        return SpecSession.preview(spec, documents: boardDocuments)
    }()
    /// V2-18: task 2 stopped on a question.
    static let buildQuestionSession: SpecSession = {
        var spec = buildReportSession.spec
        spec.runs?[2] = TaskRun(state: .running)
        spec.runs?[2]?.question = BuildQuestion(title: "What should members see without a connection?", why: "The plan says the schedule opens in under a second, but not what happens offline. Members often open it on the way to class.", options: [
            .init(label: "Show the last loaded schedule", means: "Members see classes on the subway; booking still needs a connection.", suggested: true),
            .init(label: "Show “You’re offline”", means: "Simpler. Members see nothing until they’re back online."),
        ])
        return SpecSession.preview(spec, documents: boardDocuments)
    }()
    /// V2-20: Run on task 2 refused over uncommitted changes.
    static let buildBlockedSession = SpecSession.preview(buildReportSession.spec, documents: boardDocuments, blockedRun: .init(task: 2, files: ["androidApp/AppNavigation.kt", "shared/booking/Booking.kt", "README.md", "notes.txt"]))
    /// V2-3 with every task done.
    static let builtSession: SpecSession = {
        var spec = tokens
        spec.build = .done
        spec.taskCount = 5
        spec.runs = Dictionary(uniqueKeysWithValues: (1...5).map { ($0, TaskRun(state: .done, at: .now)) })
        return SpecSession.preview(spec, documents: boardDocuments)
    }()
    /// V2-22: every task run in Mel on the spec branch, ready to merge into main.
    static func builtInMel(_ change: (inout Spec) -> Void = { _ in }) -> Spec {
        var spec = builtSession.spec
        spec.base = "main"
        spec.runs?[2]?.report = BuildReport(works: ["Members can book a class."], decisions: [.init(title: "Bookings close 1 hour before class", why: "Teachers asked for time to prepare.", instead: "Until class starts: last-minute bookings.")])
        change(&spec)
        return spec
    }
    static let builtInMelSession = SpecSession.preview(builtInMel(), documents: boardDocuments)
    /// V2-23: main changed meanwhile; 2 files conflict.
    static let mergeConflictSession = SpecSession.preview(builtInMel(), documents: boardDocuments, mergeConflict: .init(files: ["androidApp/AppNavigation.kt", "shared/booking/BookingStore.kt"], tokens: 6_200))
    /// V2-23 after Let Claude Code resolve it: the report, then Merge into main.
    static let conflictResolvedSession = SpecSession.preview(builtInMel(), documents: boardDocuments, resolveReport: BuildReport(works: ["The schedule keeps main’s new teacher filter and the booking button from task 2."]))
    static let mergedLocallySession = SpecSession.preview(builtInMel { $0.mergedInto = "main" }, documents: boardDocuments)
    /// GH-4: every task checked and pushed, the pull request open; `checks` is GitHub's now.
    static func pullRequestSession(_ checks: [PullRequestStatus.Check.Outcome], merged: Bool = false, pushError: String? = nil) -> SpecSession {
        var spec = builtSession.spec
        spec.runs = spec.runs?.mapValues { var run = $0; run.pushed = true; return run }
        spec.pullRequest = PullRequest(number: 14, url: URL(string: "https://github.com/kaanf/yoga-studio-booking/pull/14")!, merged: merged)
        let names = ["build", "test", "lint"]
        let status = PullRequestStatus(state: merged ? .merged : .open, checks: zip(names, checks).map { .init(name: $0, outcome: $1) })
        return SpecSession.preview(spec, documents: boardDocuments, pullStatus: status, pushError: pushError)
    }
    static let pullRequestChecking = pullRequestSession([.passed, .pending, .passed])
    static let pullRequestReady = pullRequestSession([.passed, .passed, .passed])
    static let pullRequestFailed = pullRequestSession([.passed, .failed, .passed])
    static let pullRequestMerged = pullRequestSession([.passed, .passed, .passed], merged: true)
    static let quickFixDoneSession = SpecSession.preview(
        Spec(name: "Double booking on fast taps", idea: "Two quick taps on Book create two bookings.", size: .quickFix, folder: project.folder.appending(path: "specs/double-booking"), stage: .done, docs: [.spec: .approved]),
        documents: [.spec: "# Spec\n\n## What happens now\n\n1. Open a class with free spots.\n2. Tap Book twice quickly.\n3. Two bookings appear and two credits are gone.\n\n## What should happen\n\n- 1 WHEN a member taps Book twice quickly, THEN one booking is made and one credit is deducted.\n\n## Must not change\n\n- WHEN a member books two different classes, THEN both bookings are made.\n- WHEN a class is full, THEN the app offers the waitlist.\n\n## Check\n\n`./gradlew :shared:allTests --tests \"*DoubleBooking*\"` fails today and passes after the fix.\n"]
    )
}
