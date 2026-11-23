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
    static let analyzeIssues = spec(.analyze, docs(.approved, .approved, .approved, .approved, .approved), analyze: .issues(4))
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
        structure: "# Structure\n\nFeature-first packages under shared/feature/<name>. One ViewModel per screen.\n\n## Modules\n\n- shared — shared/\n- androidApp — androidApp/\n- iosApp — iosApp/",
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

    static func appState(_ specs: [Spec] = [discovery], agent: AgentStatus = ready, projects: [Project] = [project], foundRepositories: [FoundRepository] = [], projectSetup: ProjectSetup? = nil, missing: [URL] = []) -> AppState {
        let state = AppState.preview(specs, agent: agent, projects: projects, foundRepositories: foundRepositories, projectSetup: projectSetup)
        state.missingFolders = missing
        return state
    }
}
