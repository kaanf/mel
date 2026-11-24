import SwiftUI
import MelSpec

/// B3 Drafting (design/v2 Native-2b-Drafting): the agent writing one file, running or stopped.
/// A stop the user didn't ask for opens the failure sheet. Pause is hidden in v0.3 (V2 §2).
struct DraftingView: View {
    let session: SpecSession
    let kind: DocKind
    @Binding var showInspector: Bool
    @State private var dismissedFailure = false
    @State private var width: CGFloat = .infinity
    @State private var showsLog = false

    private var spec: Spec { session.spec }

    private var stopReason: StopReason? {
        if case .stopped(let stopped, let reason) = spec.stage, stopped == kind { reason } else { nil }
    }

    private var isStopped: Bool { !session.isRunning && spec.docs[kind] == .stopped }

    private var failure: StopReason? {
        guard let stopReason, stopReason != .user, !dismissedFailure else { return nil }
        return stopReason
    }

    private var steps: [String] { kind.draftSteps }
    /// The step in progress (or where it stopped): `draftStep` is the last marker reached, 1-based.
    private var active: Int { min(max(session.draftStep, 1), steps.count) - 1 }
    private var done: Int { active }

    private var compact: Bool { width < ToolbarStatus.fullTextWidth }

    @ViewBuilder
    private var status: some View {
        let count = "\(active + 1) of \(steps.count)"
        let progress = Double(done) / Double(max(steps.count, 1))
        if isStopped {
            StatusPill(indicator: .idle, text: compact ? "Stopped" : "Stopped · \(done) of \(steps.count) steps saved", count: "", progress: progress, maxWidth: compact ? Theme.Size.statusPillCompact : Theme.Size.statusPillDrafting)
        } else {
            StatusPill(indicator: .running, text: compact ? "Running" : "Running · \(steps[active])", count: count, progress: progress, maxWidth: compact ? Theme.Size.statusPillCompact : Theme.Size.statusPillDrafting)
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Space.x20) {
                StageStepper(steps: ["Idea", "Questions", "Draft \(kind.title)", "Review"], current: 2)
                    .padding(.horizontal, Theme.Space.x12)
                if isStopped { stoppedBanner }
                VStack(alignment: .leading, spacing: Theme.Space.x6) {
                    HStack(alignment: .firstTextBaseline, spacing: Theme.Space.x8) {
                        Text(kind.fileName)
                            .textStyle(Theme.Text.bodyBold)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .accessibilityAddTraits(.isHeader)
                        Text("Claude Code")
                            .textStyle(Theme.Text.caption)
                            .foregroundStyle(Theme.Colors.secondaryLabel)
                    }
                    .padding(.horizontal, Theme.Space.x12)
                    stepList
                    activityLog.padding(.horizontal, Theme.Space.x12)
                }
                upNext
            }
            .foregroundStyle(Theme.Colors.label)
            .frame(maxWidth: Theme.Size.intakeWidth)
            .padding(EdgeInsets(top: Theme.Space.x12, leading: Theme.Space.x24, bottom: Theme.Space.x32, trailing: Theme.Space.x24))
            .frame(maxWidth: .infinity)
        }
        .background(Theme.Colors.background)
        .navigationTitle("Drafting")
        .navigationSubtitle(spec.name)
        .toolbar {
            // Two items, not one: NSToolbar doesn't widen an item whose content grows.
            if compact {
                ToolbarItem(placement: .principal) { status }.sharedBackgroundVisibility(.hidden)
            } else {
                ToolbarItem(placement: .principal) { status }.sharedBackgroundVisibility(.hidden)
            }
            if !isStopped {
                ToolbarItem {
                    Button { Task { await session.stop() } } label: {
                        HStack(spacing: Theme.Space.x6) {
                            DesignIcon(glyph: .stop, size: Theme.Size.alertIcon)
                            Text("Stop").textStyle(Theme.Text.body)
                        }
                        .foregroundStyle(Theme.Colors.label)
                        .padding(.horizontal, Theme.Space.x6)
                    }
                    .help("Stops the agent. Everything written so far is kept.")
                }
            }
            ToolbarItem {
                Button { showInspector.toggle() } label: {
                    DesignIcon(glyph: .inspector, size: Theme.Size.settingsIcon).foregroundStyle(Theme.Colors.label)
                }
                .accessibilityLabel(showInspector ? "Hide live preview" : "Show live preview")
                .help("Show or hide the live preview")
            }
        }
        .inspector(isPresented: $showInspector) {
            // While running the streamed text; stopped, the file as saved ("Nothing was lost").
            LivePreview(text: isStopped ? session.documents[kind] ?? "" : session.liveText, kind: kind, isRunning: !isStopped)
                .inspectorColumnWidth(min: Theme.Size.livePreviewWidth, ideal: Theme.Size.livePreviewWidth, max: Theme.Size.livePreviewWidth)
        }
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = $0 }
        .focusedSceneValue(\.inspectorShown, $showInspector)
        .sheet(isPresented: Binding(get: { failure != nil }, set: { if !$0 { dismissedFailure = true } })) {
            if let failure {
                FailureSheet(session: session, kind: kind, reason: failure)
            }
        }
    }

    private var stoppedBanner: some View {
        HStack(spacing: Theme.Space.x12) {
            VStack(alignment: .leading, spacing: Theme.Space.x2) {
                Text("Stopped. Nothing was lost.")
                    .textStyle(Theme.Text.bodyBold)
                // A run that didn't start (another spec running, Claude Code not ready) says why.
                Text(session.lastError ?? "What the agent wrote so far is saved in \(kind.fileName). You can review it now or let the agent continue.")
                    .textStyle(Theme.Text.callout)
                    .foregroundStyle(Theme.Colors.secondaryLabel)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Button("Continue Drafting") { Task { await session.resume() } }
                .buttonStyle(DesignButtonStyle(role: .secondary, height: Theme.Size.button, leading: Theme.Space.x16, trailing: Theme.Space.x16, text: Theme.Text.body))
            Button("Review What’s Written") { session.finishByHand() }
                .buttonStyle(DesignButtonStyle(height: Theme.Size.button, leading: Theme.Space.x16, trailing: Theme.Space.x16, elevation: .init()))
        }
        .padding(Theme.Space.x12)
        .background(Theme.Colors.fill, in: RoundedRectangle(cornerRadius: Theme.Radius.box))
    }

    /// The file's fixed checklist: done, the one in progress (or where it stopped), then next.
    private var stepList: some View {
        VStack(spacing: 0) {
            ForEach(steps.indices, id: \.self) { index in
                HStack(spacing: Theme.Space.x10) {
                    Group {
                        if index < done {
                            DesignIcon(glyph: .check, size: Theme.Size.stepCheck, weight: 2.2).foregroundStyle(Theme.Colors.success)
                        } else if index == active && !isStopped {
                            StatusDot(style: .running)
                        } else {
                            StatusDot(style: .ring(Theme.Colors.secondaryLabel))
                        }
                    }
                    .frame(width: Theme.Size.stepIcon, height: Theme.Size.stepIcon)
                    Text(steps[index])
                        .textStyle(Theme.Text.body)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text(index < done ? "Done" : index == active ? (isStopped ? "Stopped" : "Running") : "Next")
                        .textStyle(Theme.Text.caption)
                        .foregroundStyle(Theme.Colors.secondaryLabel)
                }
                .frame(minHeight: Theme.Size.stepRow)   // CSS min-height leaves out the padding
                .padding(.vertical, Theme.Space.x6)
                .padding(.horizontal, Theme.Space.x12)
                .accessibilityElement(children: .combine)
            }
        }
        .padding(.vertical, Theme.Space.x4)
        .background(Theme.Colors.fill, in: RoundedRectangle(cornerRadius: Theme.Radius.box))
    }

    private var activityLog: some View {
        VStack(alignment: .leading, spacing: Theme.Space.x6) {
            Button { showsLog.toggle() } label: {
                HStack(spacing: Theme.Space.x4) {
                    DesignIcon(glyph: .chevronRight, size: Theme.Size.rowChevron)
                        .rotationEffect(.degrees(showsLog ? 90 : 0))
                        .animation(.timingCurve(0.25, 0.46, 0.45, 0.94, duration: 0.15), value: showsLog)
                    Text("Activity Log").textStyle(Theme.Text.callout)
                }
                .foregroundStyle(Theme.Colors.link)
                .frame(height: Theme.Size.buttonMini)
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityValue(showsLog ? "Expanded" : "Collapsed")
            if showsLog {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(session.activity) { line in
                        Text("\(Text(line.at, format: .dateTime.hour(.twoDigits(amPM: .omitted)).minute().second()).foregroundStyle(Theme.Colors.secondaryLabel)) \(line.text)")
                            .textStyle(Theme.Text.codeLog)
                    }
                }
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, Theme.Space.x10)
                .padding(.horizontal, Theme.Space.x12)
                .background(Theme.Colors.fill, in: RoundedRectangle(cornerRadius: Theme.Radius.row))
            }
        }
    }

    @ViewBuilder
    private var upNext: some View {
        let files = spec.size.files
        let later = Array(files.drop { $0 != kind }.dropFirst())
        if !later.isEmpty {
            VStack(alignment: .leading, spacing: Theme.Space.x6) {
                Text("Up Next")
                    .textStyle(Theme.Text.bodyBold)
                    .padding(.horizontal, Theme.Space.x12)
                    .accessibilityAddTraits(.isHeader)
                VStack(spacing: 0) {
                    ForEach(later.indices, id: \.self) { index in
                        let next = later[index]
                        let previous = files[files.firstIndex(of: next)! - 1]
                        if index > 0 {
                            Rectangle().fill(Theme.Colors.separator).frame(height: Theme.Size.hairline).padding(.leading, Theme.Size.stepSeparatorInset)
                        }
                        HStack(spacing: Theme.Space.x10) {
                            DesignIcon(glyph: .lock, size: Theme.Size.stepCheck).foregroundStyle(Theme.Colors.secondaryLabel)
                            Text(index == later.count - 1 && spec.size.hasAnalyze ? "\(next.fileName), then Analyze" : next.fileName)
                                .textStyle(Theme.Text.code)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Text("Starts after you approve \(previous.title)")
                                .textStyle(Theme.Text.caption)
                                .foregroundStyle(Theme.Colors.secondaryLabel)
                        }
                        .padding(.horizontal, Theme.Space.x12)
                        .frame(height: Theme.Size.upNextRow)
                        .accessibilityElement(children: .combine)
                    }
                }
                .background(Theme.Colors.fill, in: RoundedRectangle(cornerRadius: Theme.Radius.box))
                if !isStopped {
                    HStack(spacing: Theme.Space.x6) {
                        DesignIcon(glyph: .bell, size: Theme.Size.smallCheck)
                        Text("You can switch apps. You’ll get a notification when \(kind.title) is ready to review.")
                            .textStyle(Theme.Text.caption)
                    }
                    .foregroundStyle(Theme.Colors.secondaryLabel)
                    .padding(EdgeInsets(top: Theme.Space.x2, leading: Theme.Space.x12, bottom: 0, trailing: Theme.Space.x12))
                }
            }
        }
    }
}

/// B3 live preview: a compact, read-only reading of the file while the agent writes it
/// (headings, story text, criteria counted), with a purple caret at the end while running.
struct LivePreview: View {
    let text: String
    let kind: DocKind
    let isRunning: Bool
    @State private var blocks: [Block] = []

    /// One line of the preview.
    private enum Line: Hashable {
        case title(String), heading(String), text(String), count(String)
    }

    private var lines: [Line] {
        var lines: [Line] = []
        var criteria = 0, tasks = 0
        func flush() {
            if criteria > 0 { lines.append(.count(criteria == 1 ? "1 acceptance criterion" : "\(criteria) acceptance criteria")) }
            if tasks > 0 { lines.append(.count(tasks == 1 ? "1 task" : "\(tasks) tasks")) }
            criteria = 0
            tasks = 0
        }
        for block in blocks {
            switch block {
            case .criterion: criteria += 1
            case .task: tasks += 1
            case .heading(let level, let text):
                flush()
                lines.append(level == 1 ? .title(text) : .heading(text))
            case .paragraph(let text), .listItem(let text), .assumption(_, let text), .openQuestion(_, let text), .orderedItem(_, let text):
                flush()
                lines.append(.text(text))
            default: break
            }
        }
        flush()
        return lines
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: Theme.Space.x8) {
                Text("Live Preview")
                    .textStyle(Theme.Text.bodyBold)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityAddTraits(.isHeader)
                Text(kind.fileName)
                    .textStyle(Theme.Text.codeCaption)
                    .foregroundStyle(Theme.Colors.secondaryLabel)
            }
            .padding(EdgeInsets(top: 0, leading: Theme.Space.x16, bottom: Theme.Space.x4, trailing: Theme.Space.x16))
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Space.x8) {
                    let lines = lines
                    ForEach(lines.indices, id: \.self) { index in
                        line(lines[index], isFirst: index == 0, isLast: index == lines.count - 1)
                    }
                }
                .foregroundStyle(Theme.Colors.label)
                .padding(EdgeInsets(top: Theme.Space.x4, leading: Theme.Space.x16, bottom: Theme.Space.x16, trailing: Theme.Space.x16))
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .defaultScrollAnchor(.top, for: .alignment)
            .defaultScrollAnchor(.bottom, for: .sizeChanges)   // follow the agent as the file grows
            Text("Read only while the agent writes. You can edit once it’s ready for review.")
                .textStyle(Theme.Text.caption)
                .foregroundStyle(Theme.Colors.secondaryLabel)
                .padding(EdgeInsets(top: 0, leading: Theme.Space.x16, bottom: Theme.Space.x16, trailing: Theme.Space.x16))
        }
        .background(Theme.Colors.background)
        .task(id: text) {
            blocks = await parseDocument(text, kind: kind).0
        }
    }

    @ViewBuilder
    private func line(_ line: Line, isFirst: Bool, isLast: Bool) -> some View {
        switch line {
        case .title(let text):
            Text(MarkdownBlocksView.inline(text)).textStyle(Theme.Text.headlineBold)
        case .heading(let text):
            Text(MarkdownBlocksView.inline(text)).textStyle(Theme.Text.bodyBold).padding(.top, isFirst ? 0 : Theme.Space.x4)
        case .text(let text):
            if isLast && isRunning {
                // The caret follows the last word, as drawn.
                Text("\(MarkdownBlocksView.inline(text))\(Text(" \u{258F}").foregroundStyle(Theme.Colors.drafting))").textStyle(Theme.Text.calloutLoose)
            } else {
                Text(MarkdownBlocksView.inline(text)).textStyle(Theme.Text.calloutLoose)
            }
        case .count(let text):
            Text(text).textStyle(Theme.Text.calloutLoose).foregroundStyle(Theme.Colors.secondaryLabel)
        }
    }
}

#Preview("Running") {
    @Previewable @State var showInspector = true
    NavigationStack {
        DraftingView(session: PreviewData.draftingSession, kind: .requirements, showInspector: $showInspector)
    }
    .frame(width: 1048, height: 800)
}

#Preview("Stopped") {
    @Previewable @State var showInspector = false
    NavigationStack {
        DraftingView(session: PreviewData.session(PreviewData.stoppedByUser), kind: .requirements, showInspector: $showInspector)
    }
    .frame(width: 800, height: 760)
}

#Preview("Usage limit") {
    @Previewable @State var showInspector = false
    NavigationStack {
        DraftingView(session: PreviewData.session(PreviewData.usageLimit), kind: .architecture, showInspector: $showInspector)
    }
    .environment(PreviewData.appState([PreviewData.usageLimit]))
    .frame(width: 800, height: 760)
}

#Preview("Live preview") {
    LivePreview(text: PreviewData.liveRequirements, kind: .requirements, isRunning: true)
        .frame(width: Theme.Size.livePreviewWidth, height: 600)
}
