import SwiftUI
import MelSpec

/// The board's center while no file is open: Plan (stories in First version and Later),
/// Flow (New product) and Roadmap. The plan is the files' summary; Flow and Roadmap need no agent run.
struct BoardPlan: View {
    let session: SpecSession
    /// Opens a file in the board's center (a Flow card opens EXPERIENCE.md).
    var open: (BoardFile) -> Void = { _ in }

    enum Tab: String, CaseIterable { case plan = "Plan", flow = "Flow", roadmap = "Roadmap" }

    @State private var tab: Tab
    @State private var confirming: String?

    init(session: SpecSession, tab: Tab = .plan, open: @escaping (BoardFile) -> Void = { _ in }) {
        self.session = session
        self.open = open
        _tab = State(initialValue: tab)
    }

    private var spec: Spec { session.spec }
    private var stories: [Story] { session.stories }
    private var tabs: [Tab] { Tab.allCases.filter { $0 != .flow || spec.size.files.contains(.experience) } }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.x12) {
            if spec.size != .quickFix {
                HStack(spacing: Theme.Space.x2) {
                    ForEach(tabs, id: \.self) { item in
                        Button(item.rawValue) { withAnimation(.board) { tab = item } }
                            .buttonStyle(BoardSegmentStyle(isSelected: tab == item, height: Theme.Size.buttonSmall, padding: Theme.Space.x16, text: tab == item ? Theme.Text.bodyBold : Theme.Text.body))
                            .accessibilityAddTraits(tab == item ? .isSelected : [])
                    }
                }
                .padding(Theme.Space.x2)
                .background(Theme.Colors.badgeFill, in: Capsule())
            }
            switch tab {
            case .plan: plan.frame(maxWidth: Theme.Size.planMaxWidth, alignment: .leading)
            case .flow: flow.frame(maxWidth: Theme.Size.planTabMaxWidth, alignment: .leading)
            case .roadmap: roadmap.frame(maxWidth: Theme.Size.planTabMaxWidth, alignment: .leading)
            }
        }
        // A story changing group, a removed one, the plan filling in as files are written.
        .animation(.board, value: stories.map { $0.id + ($0.isFirst ? "+" : "-") })
        .animation(.board, value: confirming)
        .animation(.board, value: spec.written)
    }

    // MARK: Plan

    @ViewBuilder
    private var plan: some View {
        if spec.size == .quickFix {
            quickFix
        } else if stories.isEmpty {
            VStack(alignment: .leading, spacing: Theme.Space.x12) {
                BoardSkeleton()
                Text("The stories appear here once REQUIREMENTS.md is written.")
                    .textStyle(Theme.Text.callout)
                    .foregroundStyle(Theme.Colors.secondaryLabel)
            }
        } else {
            let first = stories.filter(\.isFirst), later = stories.filter { !$0.isFirst }
            VStack(alignment: .leading, spacing: Theme.Space.x10) {
                group(first, isLater: false)
                group(later, isLater: true).padding(.top, Theme.Space.x10)
                mustAlso.padding(.top, Theme.Space.x10)
            }
        }
    }

    private func group(_ stories: [Story], isLater: Bool) -> some View {
        VStack(alignment: .leading, spacing: Theme.Space.x10) {
            HStack(alignment: .firstTextBaseline, spacing: Theme.Space.x8) {
                Text(isLater ? "Later" : "First version")
                    .textStyle(Theme.Text.boardTitle)
                    .foregroundStyle(isLater ? Theme.Colors.secondaryLabel : Theme.Colors.label)
                    .accessibilityAddTraits(.isHeader)
                Text("\(stories.count) \(stories.count == 1 ? "story" : "stories")").textStyle(Theme.Text.callout).foregroundStyle(Theme.Colors.secondaryLabel)
                Spacer(minLength: 0)
                if !isLater {
                    Text("Drag a story between groups. It changes at once.").textStyle(Theme.Text.caption).foregroundStyle(Theme.Colors.secondaryLabel)
                }
            }
            ForEach(stories) { story in
                storyCard(story, isLater: isLater)
            }
            if stories.isEmpty {
                Text(isLater ? "Drag a story here to leave it for later." : "Drag a story here to build it first.")
                    .textStyle(Theme.Text.callout)
                    .foregroundStyle(Theme.Colors.secondaryLabel)
                    .frame(maxWidth: .infinity)
                    .padding(Theme.Space.x14)
                    .surface(.clear, Theme.Elevation(ring: .ink(0.12), ringWidth: 1, insetRing: true), in: RoundedRectangle(cornerRadius: Theme.Radius.card))
            }
        }
        .dropDestination(for: String.self) { ids, _ in
            guard let id = ids.first, !session.isRunning else { return false }
            session.moveStory(id, toLater: isLater)
            return true
        }
    }

    private func storyCard(_ story: Story, isLater: Bool) -> some View {
        VStack(alignment: .leading, spacing: Theme.Space.x10) {
            HStack(spacing: Theme.Space.x10) {
                Grip()
                VStack(alignment: .leading, spacing: Theme.Space.x2) {
                    Text(story.title).textStyle(Theme.Text.storyTitle).foregroundStyle(isLater ? Theme.Colors.bodyLabel : Theme.Colors.label)
                    if !story.line.isEmpty {
                        Text(story.line).textStyle(Theme.Text.calloutLoose).foregroundStyle(isLater ? Theme.Colors.secondaryLabel : Theme.Colors.bodyLabel)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Button(isLater ? "First" : "Later") { session.moveStory(story.id, toLater: !isLater) }
                    .buttonStyle(BoardPillStyle(kind: isLater ? .white : .quiet, height: Theme.Size.buttonSmall, padding: Theme.Space.x10))
                    .accessibilityLabel((isLater ? "Move to first version: " : "Move to later: ") + story.title)
                Menu {
                    Button(isLater ? "Move to first version" : "Move to Later") { session.moveStory(story.id, toLater: !isLater) }
                    Button("Remove…", role: .destructive) { confirming = story.id }
                } label: {
                    HStack(spacing: Theme.Space.x2) {
                        ForEach(0..<3, id: \.self) { _ in Circle().frame(width: Theme.Size.moreDot, height: Theme.Size.moreDot) }
                    }
                    .foregroundStyle(Theme.Colors.bodyLabel)
                    .frame(width: Theme.Size.buttonSmall, height: Theme.Size.buttonSmall)
                    .surface(isLater ? Theme.Colors.background : Theme.Colors.chipFill, isLater ? .pill : .init(), in: Circle())
                }
                .menuStyle(.button)
                .buttonStyle(.plain)
                .menuIndicator(.hidden)
                .fixedSize()
                .accessibilityLabel("More for \(story.title)")
            }
            .disabled(session.isRunning)
            if confirming == story.id {
                removeConfirmation(story).transition(.drop)
            }
        }
        .padding(.vertical, Theme.Space.x12)
        .padding(.horizontal, Theme.Space.x14)
        .surface(isLater ? Theme.Colors.fillSubtle : Theme.Colors.background, isLater ? .outlineReplaced : .storyCard, in: RoundedRectangle(cornerRadius: Theme.Radius.card))
        .transition(.opacity)
        .draggable(story.id)
    }

    /// V2-8: what goes with the story, found by ID.
    private func removeConfirmation(_ story: Story) -> some View {
        VStack(alignment: .leading, spacing: Theme.Space.x8) {
            Text("Remove “\(story.title)”?").textStyle(Theme.Text.bodyBold)
            if let also = session.removal(ofStory: story.id)?.summary, !also.isEmpty {
                Text(also).textStyle(Theme.Text.calloutLoose).foregroundStyle(Theme.Colors.bodyLabel)
            }
            Text("You can restore it from DECISIONS.md.").textStyle(Theme.Text.captionLoose).foregroundStyle(Theme.Colors.secondaryLabel)
            HStack(spacing: Theme.Space.x8) {
                Button("Remove") {
                    confirming = nil
                    Task { await session.removeStory(story.id) }
                }
                .buttonStyle(BoardPillStyle(kind: .destructive))
                Button("Cancel") { confirming = nil }.buttonStyle(BoardPillStyle())
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, Theme.Space.x10)
        .padding(.horizontal, Theme.Space.x12)
        .background(Theme.Colors.fill, in: RoundedRectangle(cornerRadius: Theme.Radius.box))
    }

    /// "It must also": the quality requirements.
    @ViewBuilder
    private var mustAlso: some View {
        let quality = (session.blocks[.requirements] ?? []).compactMap { block -> String? in
            if case .criterion(let id, let text) = block, id.hasPrefix("Q") { text.replacingOccurrences(of: "THE APP SHALL ", with: "").capitalizedFirst } else { nil }
        }
        if !quality.isEmpty {
            VStack(alignment: .leading, spacing: Theme.Space.x8) {
                Text("It must also").textStyle(Theme.Text.calloutBold).foregroundStyle(Theme.Colors.bodyLabel)
                FlowLayout(spacing: Theme.Space.x6) {
                    ForEach(quality, id: \.self) { text in
                        Text(text)
                            .textStyle(Theme.Text.callout)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.vertical, Theme.Space.x5)
                            .padding(.horizontal, Theme.Space.x10)
                            .frame(minHeight: Theme.Size.buttonSmall)
                            .background(Theme.Colors.chipFill, in: RoundedRectangle(cornerRadius: Theme.Size.buttonSmall / 2))
                    }
                }
            }
        }
    }

    /// Quick fix has one file and no stories: the plan is its summary line.
    private var quickFix: some View {
        VStack(alignment: .leading, spacing: Theme.Space.x12) {
            if spec.written.isEmpty {
                BoardSkeleton()
            }
            Text(spec.written.isEmpty ? "Mel is writing SPEC.md." : "SPEC.md is written. Open it from Files to read or edit it.")
                .textStyle(Theme.Text.callout)
                .foregroundStyle(Theme.Colors.secondaryLabel)
        }
    }

    // MARK: Flow

    /// V2-16: each flow of EXPERIENCE.md as screen cards with their states, its branches below.
    @ViewBuilder
    private var flow: some View {
        let flows = ExperienceFlow.parse(session.blocks[.experience] ?? [])
        if flows.isEmpty {
            Text("The flows appear here once EXPERIENCE.md is written.").textStyle(Theme.Text.callout).foregroundStyle(Theme.Colors.secondaryLabel)
        } else {
            let screens = flows.reduce(0) { $0 + $1.screens.count + $1.branches.count }
            let missing = flows.reduce(0) { $0 + $1.screens.reduce(0) { $0 + $1.states.filter { $0.hasPrefix("!") }.count } }
            VStack(alignment: .leading, spacing: Theme.Space.x14) {
                Text("\(count(flows.count, "flow")) · \(count(screens, "screen"))" + (missing > 0 ? " · \(count(missing, "state")) not described" : ""))
                    .textStyle(Theme.Text.body)
                    .foregroundStyle(Theme.Colors.secondaryLabel)
                ForEach(Array(flows.enumerated()), id: \.offset) { index, flow in
                    section(number: index + 1, name: flow.title, meta: flow.covers.isEmpty ? "" : "Covers " + flow.covers.joined(separator: ", ")) {
                        FlowLayout(spacing: Theme.Space.x6) {
                            ForEach(Array(flow.screens.enumerated()), id: \.offset) { step, screen in
                                HStack(spacing: Theme.Space.x6) {
                                    screenCard(screen)
                                    if step < flow.screens.count - 1 {
                                        DesignIcon(glyph: .flowArrowLong, size: Theme.Space.x16).foregroundStyle(Theme.Colors.tertiary)
                                    }
                                }
                            }
                        }
                        ForEach(flow.branches, id: \.self) { branch in
                            HStack(spacing: Theme.Space.x8) {
                                DesignIcon(glyph: .flowBranch, size: Theme.Space.x14).foregroundStyle(Theme.Colors.tertiary)
                                Text(branch.when).textStyle(Theme.Text.calloutLoose).foregroundStyle(Theme.Colors.bodyLabel)
                                Button { open(.doc(.experience)) } label: {
                                    HStack(spacing: Theme.Space.x6) {
                                        Text(branch.to).textStyle(Theme.Text.calloutBold)
                                        Text(branch.ids.joined(separator: ", ")).textStyle(Theme.Text.callout).foregroundStyle(Theme.Colors.secondaryLabel).monospacedDigit()
                                    }
                                    .padding(.horizontal, Theme.Space.x10)
                                    .frame(height: Theme.Size.buttonSmall)
                                    .surface(Theme.Colors.background, .flowChip, in: Capsule())
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.leading, Theme.Space.x8)
                        }
                    }
                }
            }
        }
    }

    private func screenCard(_ screen: ExperienceFlow.Screen) -> some View {
        Button { open(.doc(.experience)) } label: {
            VStack(alignment: .leading, spacing: Theme.Space.x6) {
                Text(screen.name).textStyle(Theme.Text.bodyBold)
                FlowLayout(spacing: Theme.Space.x4) {
                    ForEach(screen.states, id: \.self) { StateChip(state: $0) }
                }
                Spacer(minLength: 0)
                Text(screen.ids.joined(separator: ", ")).textStyle(Theme.Text.caption).foregroundStyle(Theme.Colors.secondaryLabel).monospacedDigit()
            }
            .padding(Theme.Space.x10)
            .frame(width: Theme.Size.flowNode, alignment: .leading)
            .frame(maxHeight: .infinity, alignment: .topLeading)
            .surface(Theme.Colors.background, .flowNode, in: RoundedRectangle(cornerRadius: Theme.Radius.box))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(screen.name), \(screen.states.map { $0.hasPrefix("!") ? "\($0.dropFirst()) missing" : $0 }.joined(separator: ", ")). Opens EXPERIENCE.md")
    }

    // MARK: Roadmap

    /// V2-15: phases of TASKS.md, their tasks, and under each task the criteria it covers.
    @ViewBuilder
    private var roadmap: some View {
        let phases = RoadmapPhase.phases(session.tasks)
        if phases.isEmpty {
            Text("The roadmap appears here once TASKS.md is written.").textStyle(Theme.Text.callout).foregroundStyle(Theme.Colors.secondaryLabel)
        } else {
            let criteria = Dictionary((session.blocks[.requirements] ?? []).compactMap { block -> (String, String)? in
                if case .criterion(let id, let text) = block { (id, text) } else { nil }
            }, uniquingKeysWith: { first, _ in first })
            let tasks = phases.flatMap(\.tasks)
            let covered = Set(tasks.flatMap(\.covers))
            let later = stories.filter { !$0.isFirst && covered.isDisjoint(with: $0.criteria) }
            VStack(alignment: .leading, spacing: Theme.Space.x14) {
                Text("\(count(phases.count, "phase")) · \(count(tasks.count, "task")) · \(tasks.reduce(0) { $0 + $1.covers.count }) criteria")
                    .textStyle(Theme.Text.body)
                    .foregroundStyle(Theme.Colors.secondaryLabel)
                ForEach(Array(phases.enumerated()), id: \.offset) { index, phase in
                    section(number: index + 1, name: phase.name, meta: phaseMeta(phase)) {
                        ForEach(phase.tasks) { task in
                            taskCard(task, criteria: criteria)
                        }
                    }
                }
                if !later.isEmpty {
                    Text("Later, not in the roadmap yet: \(later.map(\.title).joined(separator: ", ")). Move a story to the first version to plan it.")
                        .textStyle(Theme.Text.calloutLoose)
                        .foregroundStyle(Theme.Colors.secondaryLabel)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, Theme.Space.x10)
                        .padding(.horizontal, Theme.Space.x12)
                        .surface(.clear, Theme.Elevation(ring: .ink(0.12), ringWidth: 1, insetRing: true), in: RoundedRectangle(cornerRadius: Theme.Radius.card))
                }
            }
        }
    }

    /// "2 tasks · at the same time" when the phase is one Build step.
    private func phaseMeta(_ phase: RoadmapPhase) -> String {
        let steps = BuildStep.steps(phase.tasks)
        guard phase.tasks.count > 1, steps.count == 1 else { return count(phase.tasks.count, "task") }
        return count(phase.tasks.count, "task") + (steps[0].kind == .together ? " · at the same time" : " · one after the other")
    }

    private func taskCard(_ task: SpecTask, criteria: [String: String]) -> some View {
        VStack(alignment: .leading, spacing: Theme.Space.x6) {
            HStack(alignment: .firstTextBaseline, spacing: Theme.Space.x6) {
                Text("\(task.number).").textStyle(Theme.Text.bodyBold).foregroundStyle(Theme.Colors.secondaryLabel).monospacedDigit()
                    .frame(width: Theme.Size.roadmapIndent - Theme.Space.x6, alignment: .leading)
                Text(task.title).textStyle(Theme.Text.bodyBold).frame(maxWidth: .infinity, alignment: .leading)
                if !task.priority.isEmpty {
                    Text(task.priority)
                        .textStyle(Theme.Text.caption)
                        .foregroundStyle(Theme.Colors.bodyLabel)
                        .padding(.horizontal, Theme.Space.x6)
                        .frame(height: Theme.Size.priorityChip)
                        .background(Theme.Colors.chipFill, in: Capsule())
                }
            }
            VStack(alignment: .leading, spacing: Theme.Space.x4) {
                ForEach(task.covers, id: \.self) { id in
                    HStack(alignment: .firstTextBaseline, spacing: Theme.Space.x8) {
                        Text(id).foregroundStyle(Theme.Colors.secondaryLabel).monospacedDigit().frame(width: Theme.Size.criterionID, alignment: .leading)
                        Text(criteria[id] ?? "Not in REQUIREMENTS.md").foregroundStyle(criteria[id] == nil ? Theme.Colors.secondaryLabel : Theme.Colors.label)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .textStyle(Theme.Text.calloutLoose)
                    .accessibilityElement(children: .combine)
                }
            }
            .padding(.leading, Theme.Size.roadmapIndent)
            if !task.verify.isEmpty {
                Text("Checked by: \(task.verify)").textStyle(Theme.Text.caption).foregroundStyle(Theme.Colors.secondaryLabel)
                    .padding(.leading, Theme.Size.roadmapIndent)
            }
        }
        .padding(.vertical, Theme.Space.x10)
        .padding(.horizontal, Theme.Space.x12)
        .surface(Theme.Colors.background, .fileChip, in: RoundedRectangle(cornerRadius: Theme.Radius.box))
    }

    /// A Flow or Roadmap section: number, name and a quiet line on the right, on a grey card.
    private func section(number: Int, name: String, meta: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: Theme.Space.x8) {
            HStack(spacing: Theme.Space.x8) {
                Text("\(number)")
                    .textStyle(Theme.Text.sectionNumber)
                    .foregroundStyle(Theme.Colors.bodyLabel)
                    .frame(width: Theme.Size.badge, height: Theme.Size.badge)
                    .surface(Theme.Colors.background, .flowChip, in: Circle())
                    .accessibilityHidden(true)
                Text(name).textStyle(Theme.Text.planSectionTitle).frame(maxWidth: .infinity, alignment: .leading).accessibilityAddTraits(.isHeader)
                Text(meta).textStyle(Theme.Text.caption).foregroundStyle(Theme.Colors.secondaryLabel)
            }
            content()
        }
        .padding(Theme.Space.x12)
        .background(Theme.Colors.fill, in: RoundedRectangle(cornerRadius: Theme.Radius.card))
    }

    private func count(_ n: Int, _ noun: String) -> String { "\(n) \(noun)\(n == 1 ? "" : "s")" }
}

/// A story's drag handle: six dots.
private struct Grip: View {
    var body: some View {
        VStack(spacing: Theme.Space.x5 / 2) {
            ForEach(0..<3, id: \.self) { _ in
                HStack(spacing: Theme.Size.gripWidth - 2 * Theme.Size.gripDot) {
                    Circle().frame(width: Theme.Size.gripDot, height: Theme.Size.gripDot)
                    Circle().frame(width: Theme.Size.gripDot, height: Theme.Size.gripDot)
                }
            }
        }
        .foregroundStyle(Theme.Colors.tertiary)
        .frame(width: Theme.Size.gripWidth, height: Theme.Size.gripHeight)
        .accessibilityHidden(true)
    }
}

/// A segment of the board's pill-shaped pickers (Plan tabs; Formatted / Markdown).
struct BoardSegmentStyle: ButtonStyle {
    let isSelected: Bool
    var height: CGFloat = Theme.Size.buttonMini
    var padding: CGFloat = Theme.Space.x12
    var text: Theme.TextStyle = Theme.Text.callout

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .textStyle(text)
            .foregroundStyle(Theme.Colors.label)
            .padding(.horizontal, padding)
            .frame(height: height)
            .surface(isSelected ? Theme.Colors.segmentFill : .clear, isSelected ? .segmentSelected : .init(), in: Capsule())
            .contentShape(Capsule())
    }
}

#Preview("Flow") {
    ScrollView { BoardPlan(session: PreviewData.boardSession, tab: .flow).padding(Theme.Space.x20) }
        .frame(width: 900, height: 760)
}

#Preview("Roadmap") {
    ScrollView { BoardPlan(session: PreviewData.boardSession, tab: .roadmap).padding(Theme.Space.x20) }
        .frame(width: 900, height: 760)
}

#Preview("Roadmap, no phases") {
    ScrollView { BoardPlan(session: PreviewData.boardFlatTasksSession, tab: .roadmap).padding(Theme.Space.x20) }
        .frame(width: 900, height: 760)
}
