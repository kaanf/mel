import SwiftUI
import MelSpec

/// The board's center while no file is open: Plan (stories in First version and Later),
/// Screens (New product) and Build order. The plan is the files' summary.
struct BoardPlan: View {
    let session: SpecSession

    private enum Tab: String, CaseIterable { case plan = "Plan", screens = "Screens", order = "Build order" }

    @State private var tab = Tab.plan
    @State private var confirming: String?

    private var spec: Spec { session.spec }
    private var stories: [Story] { session.stories }
    private var tabs: [Tab] { Tab.allCases.filter { $0 != .screens || spec.size.files.contains(.experience) } }

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
            case .screens: screens.frame(maxWidth: Theme.Size.screensMaxWidth, alignment: .leading)
            case .order: order
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

    // MARK: Screens

    /// Each flow of EXPERIENCE.md as a row of screens.
    @ViewBuilder
    private var screens: some View {
        let flows = BoardFlow.parse(session.blocks[.experience] ?? [])
        if flows.isEmpty {
            Text("The screens appear here once EXPERIENCE.md is written.").textStyle(Theme.Text.callout).foregroundStyle(Theme.Colors.secondaryLabel)
        } else {
            VStack(alignment: .leading, spacing: Theme.Space.x14) {
                ForEach(flows, id: \.title) { flow in
                    Text(flow.title).textStyle(Theme.Text.bodyLoose).foregroundStyle(Theme.Colors.bodyLabel)
                    FlowLayout(spacing: Theme.Space.x8) {
                        ForEach(Array(flow.screens.enumerated()), id: \.offset) { index, name in
                            HStack(spacing: Theme.Space.x8) {
                                VStack(alignment: .leading, spacing: Theme.Space.x8) {
                                    VStack(alignment: .leading, spacing: Theme.Space.x5) {
                                        Capsule().fill(Theme.Colors.skeletonStrong).frame(width: 78, height: Theme.Space.x6)
                                        RoundedRectangle(cornerRadius: Theme.Radius.keyHint).fill(Theme.Colors.skeleton).frame(height: Theme.Space.x14)
                                        RoundedRectangle(cornerRadius: Theme.Radius.keyHint).fill(Theme.Colors.skeleton).frame(height: Theme.Space.x14)
                                        Spacer(minLength: 0)
                                        Capsule().fill(Theme.Colors.accentRing).frame(width: 52, height: Theme.Space.x10)
                                    }
                                    .padding(Theme.Space.x8)
                                    .frame(height: Theme.Size.flowSketch)
                                    .background(Theme.Colors.fill, in: RoundedRectangle(cornerRadius: Theme.Radius.row))
                                    .accessibilityHidden(true)
                                    Text(name).textStyle(Theme.Text.calloutBold).lineLimit(1)
                                }
                                .padding(Theme.Space.x10)
                                .frame(width: Theme.Size.flowNode, alignment: .leading)
                                .surface(Theme.Colors.background, .flowNode, in: RoundedRectangle(cornerRadius: Theme.Radius.card))
                                if index < flow.screens.count - 1 {
                                    DesignIcon(glyph: .flowArrowLong, size: Theme.Space.x20).foregroundStyle(Theme.Colors.tertiary)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: Build order

    /// TASKS.md in build order; tasks marked "Parallel with" share a column.
    @ViewBuilder
    private var order: some View {
        let columns = BoardOrder.columns(session.tasks)
        if columns.isEmpty {
            Text("The build order appears here once TASKS.md is written.").textStyle(Theme.Text.callout).foregroundStyle(Theme.Colors.secondaryLabel)
        } else {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: Theme.Size.orderColumnMin), spacing: Theme.Space.x12, alignment: .top)], alignment: .leading, spacing: Theme.Space.x12) {
                ForEach(Array(columns.enumerated()), id: \.offset) { index, tasks in
                    VStack(alignment: .leading, spacing: Theme.Space.x8) {
                        Text("\(index + 1) · \(index == 0 ? "First" : tasks.count > 1 ? "At the same time" : "Then")")
                            .textStyle(Theme.Text.calloutHeavy)
                            .foregroundStyle(Theme.Colors.bodyLabel)
                        ForEach(tasks) { task in
                            VStack(alignment: .leading, spacing: Theme.Space.x4) {
                                Text(task.title).textStyle(Theme.Text.bodyBold)
                                if !task.verify.isEmpty {
                                    Text("Checked by: \(task.verify)").textStyle(Theme.Text.caption).foregroundStyle(Theme.Colors.secondaryLabel)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(Theme.Space.x10)
                            .surface(Theme.Colors.background, .fileChip, in: RoundedRectangle(cornerRadius: Theme.Radius.box))
                        }
                    }
                    .padding(Theme.Space.x10)
                    .background(Theme.Colors.fill, in: RoundedRectangle(cornerRadius: Theme.Radius.card))
                }
            }
        }
    }
}

/// A flow of EXPERIENCE.md: `## Flow 1 · Book a class` and its numbered screens.
struct BoardFlow {
    var title: String
    var screens: [String]

    static func parse(_ experience: [Block]) -> [BoardFlow] {
        var flows: [BoardFlow] = []
        var inFlow = false
        for block in experience {
            switch block {
            case .heading(2, let text):
                inFlow = text.hasPrefix("Flow ")
                if inFlow { flows.append(BoardFlow(title: text.split(separator: "·", maxSplits: 1).last.map { $0.trimmingCharacters(in: .whitespaces) } ?? text, screens: [])) }
            case .orderedItem(_, let text) where inFlow:
                // "Schedule (1.1)" → "Schedule"
                let name = text.split(separator: "(").first.map { $0.trimmingCharacters(in: .whitespaces) } ?? text
                flows[flows.count - 1].screens.append(name)
            default:
                break
            }
        }
        return flows.filter { !$0.screens.isEmpty }
    }
}

enum BoardOrder {
    /// Tasks in order; a task that runs parallel with one in the current column joins it.
    static func columns(_ tasks: [SpecTask]) -> [[SpecTask]] {
        var columns: [[SpecTask]] = []
        for task in tasks {
            if let last = columns.last, last.contains(where: { task.parallelWith.contains($0.number) || $0.parallelWith.contains(task.number) }) {
                columns[columns.count - 1].append(task)
            } else {
                columns.append([task])
            }
        }
        return columns
    }
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
