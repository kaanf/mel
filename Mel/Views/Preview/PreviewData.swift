import SwiftUI
import MelSpec

/// Fixtures for `#Preview`s: one yoga studio spec in every stage.
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

    /// Unanswered open question: no options, so the card shows a text field and Skip.
    static let openQuestion = Question(
        id: "q5", title: "What should the reminder message say?",
        why: "The wording sets the studio's tone; there is no right option to pick from.", shapes: .architecture, options: []
    )

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
    /// B2 as drawn: question 2 of 5, platforms answered, the mock's coverage list.
    static let intake: Spec = {
        let pending = ["Who books for whom?", "What must work offline?", "What is out of scope?"].enumerated().map { i, title in
            Question(id: "i\(i + 3)", title: title, why: "", shapes: .requirements, options: [Option(label: "Yes", note: ""), Option(label: "No", note: "")])
        }
        let questions = [
            Question(id: "i1", title: "Which platforms first?", why: "", shapes: .product,
                     options: [Option(label: "iOS and Android", note: ""), Option(label: "iOS only", note: "")], answer: .option(0, note: nil)),
            Question(id: "i2", title: "How do members pay?", why: "Decides whether the spec covers checkout, refunds and receipts.", shapes: .requirements, options: [
                Option(label: "Class packs bought in the app", note: "You mentioned buying class packs in your idea", suggested: true),
                Option(label: "Paid at the desk, app only books", note: "No checkout in the app; staff adds credits"),
                Option(label: "Monthly membership with auto-renew", note: "Subscription, unlimited booking"),
                Option(label: "Not sure yet", note: "Kept as an open question in the spec"),
            ]),
        ] + pending
        let coverage = [
            ("Goal and success metric", CoverageState.covered), ("Users and roles", .covered), ("Platforms", .covered), ("Payments", .asking),
            ("Scope and out of scope", .notYet), ("Constraints and existing code", .notYet), ("Privacy, speed, offline", .notYet),
            ("Integrations", .notYet), ("Data the app keeps", .later), ("Edge cases", .later),
        ].map { CoverageItem(label: $0, state: $1) }
        return Spec(name: "Yoga Studio Booking", idea: "An app for my yoga studio where members book classes, buy class packs and get reminders. Teachers should see who is coming to each class.",
                    folder: folder, stage: .discovery, docs: locked, questions: questions, coverage: coverage)
    }()
    static let discoveryOpen = spec(.discovery, locked, questions: Array(questions.prefix(5)) + [openQuestion])
    static let discoveryThinking = spec(.discovery, locked, questions: Array(questions.prefix(5)))
    static let drafting = spec(.drafting(.requirements), docs(.approved, .writing))
    static let stoppedByUser = spec(.stopped(.requirements, .user), docs(.approved, .stopped))
    static let usageLimit = spec(
        .stopped(.architecture, .usageLimit(resetsAt: Date(timeIntervalSince1970: 1_795_000_000))),
        docs(.approved, .approved, .approved, .stopped)
    )
    static let crashed = spec(.stopped(.architecture, .crashed("claude exited with status 1")), usageLimit.docs)
    static let review = spec(.review(.requirements), docs(.approved, .review))
    static let analyzeIssues: Spec = {
        var result = spec(.analyze, docs(.approved, .approved, .approved, .approved, .approved), analyze: .issues(4))
        result.analysis = analysis
        return result
    }()
    static let analyzeRunning = spec(.analyze, docs(.approved, .approved, .approved, .approved, .approved), analyze: .running)
    /// B6 as drawn.
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
    static let edited = spec(.review(.requirements), docs(.approved, .edited, .stale, .stale, .stale), analyze: .stale)
    static let done = spec(.done, docs(.approved, .approved, .approved, .approved, .approved), analyze: .passed)

    static let requirementsMarkdown = """
        # Requirements

        ## Story 1: Book a class

        As a member, I want to book a class from the schedule, so that I have a spot.

        1. WHEN a member taps Book on a class with free spots, THE system SHALL reserve one spot for that member.
        2. IF the class is full, THEN THE system SHALL show "Full" and offer the waiting list.

        > Assumption: Members can cancel up to 12 hours before class.
        """

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

    static let confirmedBlocks: [Block] = requirementsBlocks.filter {
        if case .assumption = $0 { false } else { true }
    }

    static let activity: [ActivityLine] = [
        ActivityLine(at: Date(timeIntervalSince1970: 1_795_000_000), text: "read PRODUCT.md and 7 answers"),
        ActivityLine(at: Date(timeIntervalSince1970: 1_795_000_030), text: "wrote story 1 \"Book a class\" (3 criteria)"),
        ActivityLine(at: Date(timeIntervalSince1970: 1_795_000_065), text: "wrote story 2 \"Cancel a booking\" (2 criteria)"),
        ActivityLine(at: Date(timeIntervalSince1970: 1_795_000_090), text: "writing story 3 of 5"),
    ]

    static func session(_ spec: Spec, isRunning: Bool = false, lastError: String? = nil, conflict: DocKind? = nil) -> SpecSession {
        SpecSession.preview(
            spec,
            documents: [.product: "# Product", .requirements: requirementsMarkdown],
            liveText: requirementsMarkdown,
            activity: activity,
            isRunning: isRunning,
            lastError: lastError,
            conflict: conflict
        )
    }

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
        principles: "# Principles\n\n1. Reuse existing modules before adding new ones. Name the module you extend.\n2. No new dependency without a short reason in ARCHITECTURE.md.\n3. Every acceptance criterion gets a test before the task counts as done.",
        read: [
            ReadItem(label: "README and docs folder", source: "README.md, docs/"),
            ReadItem(label: "Build files and dependencies", source: "build.gradle.kts"),
            ReadItem(label: "3 modules: shared, androidApp, iosApp", source: "settings.gradle.kts"),
            ReadItem(label: "2 features already built: sign-in, schedule", source: "shared/feature/"),
        ],
        sources: ["product.md": "From README", "tech.md": "Detected", "structure.md": "Detected"]
    )

    static let readLines = ["README and docs folder", "Build files and dependencies", "3 modules: shared, androidApp, iosApp", "2 features already built: sign-in, schedule"]
        .enumerated().map { ActivityLine(at: Date(timeIntervalSince1970: 1_795_000_000 + Double($0.offset)), text: $0.element) }

    static let projectSetup = ProjectSetup(project: project, isNewProject: false, isRunning: false, activity: readLines, context: context, lastError: nil, branch: "main", fileCount: 214)
    static let projectSetupRunning = ProjectSetup(project: project, isNewProject: false, isRunning: true, activity: Array(readLines.prefix(2)), context: nil, lastError: nil, branch: "main", fileCount: 214)

    static func appState(_ specs: [Spec] = [discovery], agent: AgentStatus = ready, projects: [Project] = [project], contexts: [Project.ID: ProjectContext] = [:], foundRepositories: [FoundRepository] = [], projectSetup: ProjectSetup? = nil, branches: [Project.ID: String] = [:], sessions: [SpecSession] = [], missing: [URL] = []) -> AppState {
        let state = AppState.preview(specs, agent: agent, projects: projects, contexts: contexts, foundRepositories: foundRepositories, projectSetup: projectSetup, branches: branches, sessions: sessions)
        state.missingFolders = missing
        return state
    }

    // B1 New Spec
    static let habitTracker = Project(folder: FileManager.default.homeDirectoryForCurrentUser.appending(path: "Developer/habit-tracker"))
    static let newSpecState = appState([], projects: [project, habitTracker], contexts: [project.id: context], projectSetup: projectSetup, branches: [project.id: "main", habitTracker.id: "develop"])
    static let featureDraft = NewSpecView.Draft(
        size: .feature, project: project, name: "Filter schedule by teacher",
        idea: "Members can filter the weekly schedule by teacher and see a short teacher profile on each class.",
        buildsOn: ["Schedule"]
    )
    static let featureDraftNoContext = NewSpecView.Draft(size: .feature, project: habitTracker, name: featureDraft.name, idea: featureDraft.idea)
    static let quickFixDraft = NewSpecView.Draft(
        size: .quickFix, project: project, name: "Double booking on fast taps",
        happensNow: "Two quick taps on Book create two bookings and take two credits.",
        shouldHappen: "One booking, one credit. The second tap does nothing.",
        location: "Class detail › Book button",
        files: [URL(filePath: "/tmp/crash-1123.log"), URL(filePath: "/tmp/double-tap.mov")]
    )

    // B3 Drafting as drawn: REQUIREMENTS.md at step 3, story 3 being written.
    static let liveRequirements = """
        # Requirements

        ## 1. Book a class

        As a member, I want to book a class from the weekly schedule, so that my spot is guaranteed.

        - 1.1 WHEN a member taps Book on a class with free spots, THE system SHALL reserve one spot.
        - 1.2 IF the class is full, THEN THE system SHALL offer the waiting list.
        - 1.3 WHEN a booking is made, THE system SHALL send a confirmation.

        ## 2. Buy a class pack

        As a member, I want to buy a pack of classes in the app, so that I can book without paying each time.

        - 2.1 WHEN a member buys a pack, THE system SHALL add its credits to the account.
        - 2.2 IF the payment fails, THEN THE system SHALL keep the credits unchanged.

        ## 3. Cancel a booking

        As a member, I want to cancel a booking I can’t make, so that
        """
    static let draftingActivity = [
        "read specs/PRODUCT.md (approved)", "read 5 answers, 1 left open", "wrote story 1 “Book a class” (3 criteria)",
        "wrote story 2 “Buy a class pack” (2 criteria)", "writing story 3 “Cancel a booking”",
    ].enumerated().map { ActivityLine(at: Date(timeIntervalSince1970: 1_795_000_000 + Double($0.offset * 20)), text: $0.element) }
    static let draftingSession = SpecSession.preview(
        drafting, documents: [.product: "# Product"], liveText: liveRequirements, activity: draftingActivity, isRunning: true, draftStep: 3
    )

    // B4 Review as drawn: REQUIREMENTS.md with round-2 gaps, an assumption and an open question.
    static let reviewMarkdown = """
        # Requirements

        ## 1. Book a class

        P1 · MVP

        As a member, I want to book a class from the weekly schedule, so that my spot is guaranteed.

        Source: your idea, Question 4 (cancellations)

        - 1.1 WHEN a member books a class with free spots, THE APP SHALL reserve one spot, deduct one credit and show it under Upcoming.
        - 1.2 WHEN a class is full, THE APP SHALL offer to join the waitlist instead.

        > [!ASSUMPTION]
        > The waitlist is first come, first served. When a spot frees up, the first member on it is booked automatically and notified.

        ## 2. Buy a class pack

        P1 · MVP

        As a member, I want to buy a pack of classes in the app, so that I can book without paying each time.

        Source: Question 2 (payments)

        - 2.1 WHEN a member completes payment, THE APP SHALL add the pack’s credits and email a receipt.

        > [!OPEN QUESTION]
        > What happens to unused credits when a pack expires?

        <!-- MVP line -->

        ## Quality requirements

        Source: Intake (privacy, speed, offline) and project principles

        - Q1 THE APP SHALL open the weekly schedule in under 1 second on a mid-range phone.
        - Q2 THE APP SHALL never store card data on the device.
        - Q3 WHILE offline, THE APP SHALL show the last loaded schedule and say when it was updated.

        ## Edge cases

        - Two members book the last spot at the same moment: one gets it, the other is offered the waitlist.
        - Payment succeeds but the app closes before credits show: credits appear on next open.
        """
    static let reviewRoundTwo: Spec = {
        var spec = review
        spec.questions += ["Can members book for a friend?", "Do teachers see payment status?"].enumerated().map { i, title in
            Question(id: "r\(i + 1)", title: title, why: "Found while drafting REQUIREMENTS.md.", shapes: .requirements, round: .draft,
                     options: [Option(label: "Yes", note: ""), Option(label: "No", note: "")])
        }
        return spec
    }()
    static let reviewSession = SpecSession.preview(reviewRoundTwo, documents: [.product: "# Product", .requirements: reviewMarkdown])

    // B5 Review EXPERIENCE.md as drawn.
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
    static let reviewExperience = spec(.review(.experience), docs(.approved, .approved, .review), questions: allAnswered)
    static let experienceSession = SpecSession.preview(reviewExperience, documents: [.product: "# Product", .requirements: reviewMarkdown, .experience: experienceMarkdown])
}
