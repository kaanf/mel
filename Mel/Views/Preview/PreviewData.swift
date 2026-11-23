import SwiftUI
import MelSpec

/// Fixtures for `#Preview`s: one yoga studio spec in every stage.
enum PreviewData {
    static let folder = URL(filePath: "/Users/me/Developer/yoga-studio-booking/specs")
    static let executable = URL(filePath: "/Users/me/.local/bin/claude")
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
            id: "q4", title: "Until when can members cancel?", why: "Late cancellations leave empty spots that others could have booked.", shapes: .requirements,
            options: [
                Option(label: "Any time before class", note: "Friendly, but spots can go unused."),
                Option(label: "Up to 12 hours before", note: "Common for small studios.", suggested: true),
                Option(label: "Up to 24 hours before", note: "Strict; fewer empty spots."),
            ]
        ),
    ]

    static let coverage: [CoverageItem] = [
        CoverageItem(label: "Who uses it", state: .covered),
        CoverageItem(label: "Payments", state: .covered),
        CoverageItem(label: "Schedule", state: .covered),
        CoverageItem(label: "Cancellations", state: .asking),
        CoverageItem(label: "Waiting list", state: .notYet),
        CoverageItem(label: "Notifications", state: .notYet),
        CoverageItem(label: "Teacher view", state: .notYet),
    ]

    static let allAnswered: [Question] = questions.map { question in
        var question = question
        question.answer = question.answer ?? .option(1, note: nil)
        return question
    }

    static func spec(_ stage: Stage, _ docs: [DocKind: DocStatus], questions: [Question] = allAnswered) -> Spec {
        Spec(name: "Yoga Studio Booking", idea: idea, folder: folder, stage: stage, docs: docs, questions: questions, coverage: coverage)
    }

    static let locked: [DocKind: DocStatus] = [.product: .locked, .requirements: .locked, .design: .locked, .tasks: .locked]

    static let discovery = spec(.discovery, locked, questions: questions)
    static let discoveryThinking = spec(.discovery, locked, questions: Array(questions.prefix(3)))
    static let drafting = spec(.drafting(.requirements), [.product: .approved, .requirements: .writing, .design: .locked, .tasks: .locked])
    static let stoppedByUser = spec(.stopped(.requirements, .user), [.product: .approved, .requirements: .stopped, .design: .locked, .tasks: .locked])
    static let usageLimit = spec(
        .stopped(.design, .usageLimit(resetsAt: Date(timeIntervalSince1970: 1_795_000_000))),
        [.product: .approved, .requirements: .approved, .design: .stopped, .tasks: .locked]
    )
    static let crashed = spec(.stopped(.design, .crashed("claude exited with status 1")), usageLimit.docs)
    static let review = spec(.review(.requirements), [.product: .approved, .requirements: .review, .design: .locked, .tasks: .locked])
    static let done = spec(.done, [.product: .approved, .requirements: .approved, .design: .approved, .tasks: .approved])

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

    static func appState(_ specs: [Spec] = [discovery], agent: AgentStatus = ready, missing: [URL] = []) -> AppState {
        let state = AppState.preview(specs, agent: agent)
        state.missingFolders = missing
        return state
    }
}
