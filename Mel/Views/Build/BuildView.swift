import SwiftUI
import MelSpec

/// V2-3 Build (design/v2 V2-3-Ready): the first version, task by task. The user runs each prompt in
/// their own Claude Code; Mel says what can run at the same time, what waits, and moves a task to
/// Done when its check passes on this Mac and git has its commit. ‹ Plan goes back to the board
/// (V2-10). Tell Mel opens in the right panel for what a task turned up.
struct BuildView: View {
    let session: SpecSession
    @Environment(\.openSettings) private var openSettings
    @AppStorage("settingsTab") private var settingsTab = SettingsView.Pane.agents
    @AppStorage("showTokens") private var showsTokens = true
    @AppStorage("commitSpec") private var commitsSpec = true
    @AppStorage("writeAgentsFile") private var writesAgentsFile = true
    @State private var copied: Int?
    @State private var shownPrompts: Set<Int> = []
    /// Done tasks whose report is open, and running tasks with every step shown.
    @State private var shownReports: Set<Int> = []
    @State private var shownSteps: Set<Int> = []
    /// Reports whose "not allowed" list is open.
    @State private var shownRefused: Set<Int> = []
    /// The "Something else…" answer to a task's question.
    @State private var otherAnswer = ""
    @State private var answersOther = false
    /// "Tell Mel about this": the task the next request comes from.
    @State private var telling: SpecTask?
    /// The right panel shows Tell Mel instead of How building works.
    @State private var isTelling: Bool
    /// Width inside an "At the same time" step, for how many cards go side by side.
    @State private var stepWidth = Theme.Size.buildWidth

    private var showsTell: Bool { isTelling || (session.isRunning && session.runningTask == nil) || session.lastChange != nil || spec.unplacedChange != nil }

    init(session: SpecSession, telling: SpecTask? = nil, report: Int? = nil) {
        self.session = session
        _shownReports = State(initialValue: report.map { [$0] } ?? [])
        _telling = State(initialValue: telling)
        _isTelling = State(initialValue: telling != nil)
    }

    private var spec: Spec { session.spec }
    private var tasks: [SpecTask] { session.tasks }
    private var done: Int { spec.doneCount(tasks) }
    private var allDone: Bool { !tasks.isEmpty && done == tasks.count }
    private var repo: String { spec.project.lastPathComponent }

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Space.x14) {
                    progress
                    if let blocked = session.blockedRun { blockedBanner(blocked).transition(.drop) }
                    if let error = session.pushError { pushBanner(error).transition(.drop) }
                    if allDone { builtBanner.transition(.drop) }
                    ForEach(Array(session.steps.enumerated()), id: \.offset) { index, step in
                        stepSection(step, index: index)
                    }
                    if let error = session.lastError {
                        Text(error).textStyle(Theme.Text.callout).foregroundStyle(Theme.Colors.cautionText)
                    }
                }
                .frame(maxWidth: Theme.Size.buildWidth, alignment: .leading)
                .padding(EdgeInsets(top: Theme.Space.x4, leading: Theme.Space.x20, bottom: Theme.Space.x24, trailing: Theme.Space.x20))
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        // The header takes the hidden title bar's place, level with the traffic lights.
        .ignoresSafeArea(.container, edges: .top)
        .inspector(isPresented: .constant(true)) {
            VStack(spacing: 0) {
                asideHeader
                Group {
                    if showsTell { tellPanel.transition(.opacity) } else { aside.transition(.opacity) }
                }
            }
            .ignoresSafeArea(.container, edges: .top)
            .foregroundStyle(Theme.Colors.label)
            .background(Theme.Colors.fillSubtle)
            .inspectorColumnWidth(Theme.Size.buildAside)
        }
        .foregroundStyle(Theme.Colors.label)
        .background(Theme.Colors.background)
        .animation(.board, value: spec.runs)
        .animation(.board, value: session.checking)
        .animation(.board, value: session.lastChange)
        .animation(.board, value: showsTell)
        .animation(.board, value: session.isRunning)
        .animation(.board, value: spec.unplacedChange)
        .animation(.board, value: session.blockedRun)
        .animation(.board, value: session.runningTask)
        .animation(.board, value: spec.pullRequest)
        .animation(.board, value: session.pullStatus)
        .animation(.board, value: session.pushError)
        .animation(.board, value: session.mergeConflict)
        .animation(.board, value: spec.mergedInto)
        .navigationTitle("Build: \(spec.name)")
        // GH-4: GitHub's checks while they run, and a Merge when checks pass until GitHub merges.
        .task(id: spec.pullRequest) {
            await session.refreshPullRequest()
            while !Task.isCancelled, let pull = spec.pullRequest, !pull.merged, pull.autoMerge || session.pullStatus?.pending.isEmpty == false {
                try? await Task.sleep(for: .seconds(15))
                await session.refreshPullRequest()
            }
        }
    }

    // MARK: Header

    /// The center's header: ‹ Plan, the spec's name and the build's status.
    private var header: some View {
        HStack(spacing: Theme.Space.x12) {
            Button { session.reopenPlan() } label: {
                HStack(spacing: Theme.Space.x4) {
                    DesignIcon(glyph: .chevronLeft, size: Theme.Size.rowChevron)
                    Text("Plan").textStyle(Theme.Text.callout)
                }
                .foregroundStyle(Theme.Colors.label)
                .padding(EdgeInsets(top: 0, leading: Theme.Space.x6, bottom: 0, trailing: Theme.Space.x10))
                .frame(height: Theme.Size.button)
                .background(Theme.Colors.chipFill, in: Capsule())
                .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            .help("Back to the plan. Start Building brings you here again.")
            Text("Build: \(spec.name)").textStyle(Theme.Text.bodyBold).lineLimit(1).layoutPriority(1)
            Spacer(minLength: 0)
            HStack(spacing: Theme.Space.x8) {
                StatusDot(style: dotStyle)
                Text(pill).textStyle(Theme.Text.callout).foregroundStyle(Theme.Colors.bodyLabel).lineLimit(1)
            }
            .padding(.horizontal, Theme.Space.x12)
            .frame(height: Theme.Size.button)
            .background(Theme.Colors.statusPillFill, in: Capsule())
            .accessibilityElement(children: .combine)
            if !allDone, spec.runs?.values.contains(where: \.byHand) != true {
                Button("Run the rest") { Task { await session.runRest() } }
                    .buttonStyle(BoardPillStyle(kind: .accent))
                    .disabled(session.isRunning || session.runsRest || asking != nil || session.nextTask == nil)
                    .help("Runs the open tasks one after another and stops when Mel needs you")
            }
        }
        .padding(.horizontal, Theme.Space.x20)
        .frame(height: Theme.Size.columnHeader)
        // Where the title bar was: the whole row moves the window.
        .contentShape(Rectangle())
        .gesture(WindowDragGesture())
    }

    /// Over Mel's column.
    private var asideHeader: some View {
        HStack {
            Spacer(minLength: 0)
            Button(action: session.openTerminal) {
                HStack(spacing: Theme.Space.x6) {
                    Image(systemName: "apple.terminal").font(.system(size: Theme.Size.terminalButtonIcon))
                    Text("Open Terminal here").textStyle(Theme.Text.callout)
                }
                .foregroundStyle(Theme.Colors.label)
                .padding(.horizontal, Theme.Space.x12)
                .frame(height: Theme.Size.terminalButton)
                .background(Theme.Colors.chipFill, in: Capsule())
                .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            .help("Opens Claude Code in \(repo), ready for a pasted prompt")
        }
        .padding(.horizontal, Theme.Space.x16)
        .frame(height: Theme.Size.columnHeader)
        // Where the title bar was: the whole row moves the window.
        .contentShape(Rectangle())
        .gesture(WindowDragGesture())
    }

    private var failedCount: Int { tasks.count { if case .failed = session.status(of: $0) { true } else { false } } }
    private var runningCount: Int { tasks.count { session.status(of: $0) == .running } }

    private var dotStyle: StatusDot.Style {
        if session.isRunning || (spec.pullRequest?.merged == false && session.pullStatus?.pending.isEmpty == false) { return .ring(Theme.Colors.accent) }
        if spec.pullRequest?.merged == false, session.pullStatus?.failed.isEmpty == false { return .filled(Theme.Colors.failure) }
        if session.mergeConflict != nil { return .filled(Theme.Colors.accent) }
        return .filled(allDone ? Theme.Colors.success : failedCount > 0 ? Theme.Colors.failure : Theme.Colors.accent)
    }

    private var pill: String {
        if let number = session.runningTask { return "Mel is building task \(number)" }
        if let (task, _) = asking { return "Task \(task.number) asks a question" }
        if session.isRunning { return "Mel is changing the files" }
        if let pull = spec.pullRequest {
            if pull.merged { return "Merged" }
            if session.pullStatus?.failed.isEmpty == false { return "A GitHub check failed" }
            if session.pullStatus?.pending.isEmpty == false { return "Built · checks running" }
            return "Built · ready to merge"
        }
        if let conflict = session.mergeConflict { return "Merge stopped: \(conflict.files.count) \(conflict.files.count == 1 ? "file conflicts" : "files conflict")" }
        if let base = spec.mergedInto { return "Merged into \(base)" }
        if allDone { return "First version built" }
        if failedCount > 0 { return "A check failed" }
        if runningCount > 0 { return "\(runningCount) \(runningCount == 1 ? "task" : "tasks") running" }
        return "Ready for the next task"
    }

    // MARK: Progress

    private var progress: some View {
        VStack(alignment: .leading, spacing: Theme.Space.x8) {
            HStack(alignment: .firstTextBaseline, spacing: Theme.Space.x8) {
                Text("\(done) of \(tasks.count) \(tasks.count == 1 ? "task" : "tasks") done").textStyle(Theme.Text.bodyBold)
                Text(nextLine).textStyle(Theme.Text.callout).foregroundStyle(Theme.Colors.secondaryLabel)
            }
            HStack(spacing: Theme.Space.x4) {
                ForEach(tasks) { task in
                    RoundedRectangle(cornerRadius: Theme.Size.segment / 2).fill(segmentColor(task)).frame(height: Theme.Size.segment)
                }
            }
            .accessibilityHidden(true)
        }
    }

    private var nextLine: String {
        if allDone { return "" }
        let statuses = tasks.map { ($0, session.status(of: $0)) }
        if let (task, _) = asking { return "Task \(task.number) waits for your answer." }
        if let failed = statuses.first(where: { if case .failed = $0.1 { true } else { false } }) { return "Task \(failed.0.number) needs a fix." }
        let ready = statuses.filter { $0.1 == .ready }.map(\.0.number)
        if !ready.isEmpty { return "Next: task " + ready.map(String.init).joined(separator: " and ") + (ready.count > 1 ? ", at the same time." : ".") }
        let running = statuses.filter { $0.1 == .running }.map(\.0.number)
        return running.isEmpty ? "" : "Waiting for Claude Code on task " + running.map(String.init).joined(separator: " and ") + "."
    }

    private func segmentColor(_ task: SpecTask) -> Color {
        if session.checking.contains(task.number) { return Theme.Colors.accent }
        switch session.status(of: task) {
        case .done: return Theme.Colors.success
        case .failed: return Theme.Colors.failure
        case .running: return Theme.Colors.accent
        case .stopped: return Theme.Colors.caution
        case .asking: return Theme.Colors.accent
        case .ready, .waiting: return Theme.Colors.separator
        }
    }

    /// V2-20: Run won't start over changes that aren't committed.
    private func blockedBanner(_ blocked: SpecSession.BlockedRun) -> some View {
        let shown = blocked.files.prefix(3).joined(separator: ", ") + (blocked.files.count > 3 ? " and \(blocked.files.count - 3) more" : "")
        return VStack(alignment: .leading, spacing: Theme.Space.x8) {
            Text("You have changes that aren’t committed").textStyle(Theme.Text.bodyBold).foregroundStyle(Theme.Colors.bannerTitle)
            Text("\(shown). Mel won’t start task \(blocked.task) over them, so they don’t end up in its commit.")
                .textStyle(Theme.Text.calloutLoose)
                .foregroundStyle(Theme.Colors.bodyLabel)
                .fixedSize(horizontal: false, vertical: true)
            FlowLayout(spacing: Theme.Space.x8) {
                Button("Commit them, then run") { Task { await session.clearBlockedRun(commit: true) } }.buttonStyle(BoardPillStyle(kind: .accent))
                Button("Put them aside, then run") { Task { await session.clearBlockedRun(commit: false) } }
                    .buttonStyle(BoardPillStyle())
                    .help("A git stash you can get back with git stash pop")
                Button("Cancel", action: session.cancelBlockedRun)
                    .buttonStyle(DesignLinkStyle())
                    .padding(.horizontal, Theme.Space.x4)
                    .frame(height: Theme.Size.button)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, Theme.Space.x12)
        .padding(.horizontal, Theme.Space.x14)
        .surface(Theme.Colors.bannerFill, .banner, in: RoundedRectangle(cornerRadius: Theme.Radius.card))
    }

    // MARK: Built

    @ViewBuilder
    private var builtBanner: some View {
        if let pull = spec.pullRequest { pullBanner(pull) } else if let conflict = session.mergeConflict { conflictBanner(conflict) } else { localBanner }
    }

    private var laterStories: [Story] { session.stories.filter { !$0.isFirst } }

    @ViewBuilder
    private var planLater: some View {
        let later = laterStories
        if !later.isEmpty {
            Button("Plan the \(later.count) later \(later.count == 1 ? "story" : "stories")") { session.reopenPlan() }
                .buttonStyle(BoardPillStyle(kind: spec.pullRequest?.merged == true ? .accent : .white))
        }
    }

    /// GH-4 / GH-5: the spec's pull request: Merge, Merge when checks pass, a failed check, merged.
    @ViewBuilder
    private func pullBanner(_ pull: PullRequest) -> some View {
        let status = session.pullStatus
        if let failed = status?.failed.first, !pull.merged {
            VStack(alignment: .leading, spacing: Theme.Space.x8) {
                Text("GitHub’s check “\(failed.name)” failed on #\(pull.number)").textStyle(Theme.Text.bodyBold).foregroundStyle(Theme.Colors.bannerTitle)
                Text("Its tasks passed their checks on this Mac, so it may depend on GitHub’s runner. Nothing was merged. Fix it with Tell Mel or in your terminal on \(session.branch); Mel pushes what you commit after the next Check it.")
                    .textStyle(Theme.Text.calloutLoose)
                    .foregroundStyle(Theme.Colors.bodyLabel)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: Theme.Space.x8) {
                    Button("View on GitHub", action: session.openPullRequest).buttonStyle(BoardPillStyle(kind: .accent))
                    Button("Push again") { Task { await session.publish() } }.buttonStyle(BoardPillStyle())
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, Theme.Space.x12)
            .padding(.horizontal, Theme.Space.x14)
            .surface(Theme.Colors.bannerFill, .banner, in: RoundedRectangle(cornerRadius: Theme.Radius.card))
        } else {
            let pending = status?.pending.isEmpty == false
            VStack(alignment: .leading, spacing: Theme.Space.x8) {
                HStack(spacing: Theme.Space.x8) {
                    if pull.merged { DesignIcon(glyph: .check, size: Theme.Size.doneCheck, weight: 2.2).foregroundStyle(Theme.Colors.success) }
                    Text(pull.merged ? "Merged into main on GitHub" : "The first version is built").textStyle(Theme.Text.boardTitle)
                }
                Text(pull.merged
                     ? "#\(pull.number) was squashed into one commit on main. Mel deleted \(session.branch) and switched this Mac to an up-to-date main."
                     : "All \(tasks.count) tasks are on \(session.branch). Mel opened pull request #\(pull.number) with what works now and the decisions made while building.")
                    .textStyle(Theme.Text.calloutLoose)
                    .foregroundStyle(Theme.Colors.bodyLabel)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: Theme.Space.x8) {
                    if !pull.merged {
                        Button(pull.autoMerge ? "Merges when checks pass" : pending ? "Merge when checks pass" : "Merge pull request") {
                            Task { await session.mergePullRequest(auto: pending) }
                        }
                        .buttonStyle(BoardPillStyle(kind: .accent))
                        .disabled(pull.autoMerge || session.isMerging)
                    }
                    planLater
                    Button("View on GitHub", action: session.openPullRequest).buttonStyle(BoardPillStyle())
                    if session.isMerging { ProgressView().controlSize(.small) }
                }
                if !pull.merged, let status {
                    Text(pending ? "GitHub is still running \(status.pending.count) of \(status.checks.count) checks. Mel merges as soon as they pass, even if you close this window."
                         : status.checks.isEmpty ? "Merge squashes the \(tasks.count) task commits into one on main." : "GitHub’s \(status.checks.count) checks passed. Merge squashes the \(tasks.count) task commits into one on main.")
                        .textStyle(Theme.Text.caption)
                        .foregroundStyle(Theme.Colors.secondaryLabel)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, Theme.Space.x14)
            .padding(.horizontal, Theme.Space.x16)
            .surface(Theme.Colors.resultFill, .result, in: RoundedRectangle(cornerRadius: Theme.Radius.card))
            .accessibilityElement(children: .contain)
        }
    }

    /// A push or the pull request failed (offline, rejected); the tasks stay Done.
    private func pushBanner(_ error: String) -> some View {
        VStack(alignment: .leading, spacing: Theme.Space.x8) {
            Text(error).textStyle(Theme.Text.calloutLoose).foregroundStyle(Theme.Colors.bannerTitle).fixedSize(horizontal: false, vertical: true)
            Button("Push again") { Task { await session.publish() } }.buttonStyle(BoardPillStyle())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, Theme.Space.x12)
        .padding(.horizontal, Theme.Space.x14)
        .surface(Theme.Colors.bannerFill, .banner, in: RoundedRectangle(cornerRadius: Theme.Radius.card))
    }

    /// V2-22 without GitHub: Merge into main once the tasks ran in Mel on the spec branch.
    private var localBanner: some View {
        let later = laterStories
        let byHand = spec.runs?.values.contains { $0.byHand } == true
        let inMel = spec.base != nil
        let merged = spec.mergedInto
        let decisions = tasks.reduce(0) { $0 + (spec.runs?[$1.number]?.report?.decisions.count ?? 0) }
        return VStack(alignment: .leading, spacing: Theme.Space.x8) {
            HStack(spacing: Theme.Space.x8) {
                if merged != nil { DesignIcon(glyph: .check, size: Theme.Size.doneCheck, weight: 2.2).foregroundStyle(Theme.Colors.success) }
                Text(merged.map { "Merged into \($0)" } ?? "The first version is built").textStyle(Theme.Text.boardTitle)
            }
            Text(builtText(byHand: byHand, inMel: inMel, merged: merged, decisions: decisions, later: later))
                .textStyle(Theme.Text.calloutLoose)
                .foregroundStyle(Theme.Colors.bodyLabel)
                .fixedSize(horizontal: false, vertical: true)
            if let report = session.resolveReport, merged == nil {
                VStack(alignment: .leading, spacing: Theme.Space.x4) {
                    Text("Claude Code merged \(session.baseBranch) into \(session.branch)").textStyle(Theme.Text.calloutBold)
                    ForEach(report.works + report.notDone, id: \.self) { line in
                        Text(line).textStyle(Theme.Text.captionLoose).foregroundStyle(Theme.Colors.bodyLabel).fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            HStack(spacing: Theme.Space.x8) {
                if inMel, merged == nil {
                    Button("Merge into \(session.baseBranch)") { Task { await session.mergeIntoMain() } }
                        .buttonStyle(BoardPillStyle(kind: .accent))
                        .disabled(session.isMerging || session.isRunning)
                }
                if !later.isEmpty {
                    Button("Plan the \(later.count) later \(later.count == 1 ? "story" : "stories")") { session.reopenPlan() }
                        .buttonStyle(BoardPillStyle(kind: inMel && merged == nil ? .white : .accent))
                }
                if !inMel {
                    Button("Start over", action: session.startOver)
                        .buttonStyle(DesignLinkStyle())
                        .padding(.horizontal, Theme.Space.x4)
                        .frame(height: Theme.Size.button)
                }
                if session.isMerging { ProgressView().controlSize(.small) }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, Theme.Space.x14)
        .padding(.horizontal, Theme.Space.x16)
        .surface(Theme.Colors.resultFill, .result, in: RoundedRectangle(cornerRadius: Theme.Radius.card))
        .accessibilityElement(children: .contain)
    }

    private func builtText(byHand: Bool, inMel: Bool, merged: String?, decisions: Int, later: [Story]) -> String {
        if let merged {
            return "The \(tasks.count) tasks’ commits are on \(merged). Mel deleted \(session.branch)."
        }
        let laterText = later.isEmpty ? "" : " \(later.count) \(later.count == 1 ? "story is" : "stories are") still in Later: \(later.map(\.title).joined(separator: ", "))."
        guard inMel else {
            return (byHand ? "All \(tasks.count) tasks are done." : "All \(tasks.count) tasks passed their checks.") + " The spec moved to Done." + laterText
        }
        let decided = decisions == 0 ? "" : " \(decisions) \(decisions == 1 ? "decision was" : "decisions were") made while building; they’re in each task’s report and in DECISIONS.md."
        return (byHand ? "All \(tasks.count) tasks are done" : "All \(tasks.count) tasks passed their checks") + " and are committed on \(session.branch)." + decided + laterText
    }

    /// V2-23: merging would conflict. Nothing was merged; Claude Code resolves it on the spec branch,
    /// with a report, or the user does in Terminal.
    private func conflictBanner(_ conflict: SpecSession.MergeConflict) -> some View {
        let count = conflict.files.count
        return VStack(alignment: .leading, spacing: Theme.Space.x8) {
            Text("\(session.baseBranch) changed while you built: \(count) \(count == 1 ? "file conflicts" : "files conflict")")
                .textStyle(Theme.Text.calloutBold)
                .foregroundStyle(Theme.Colors.bannerTitle)
            VStack(alignment: .leading, spacing: Theme.Space.x2) {
                ForEach(conflict.files, id: \.self) { file in
                    Text(file).textStyle(Theme.Text.codeCaptionList).foregroundStyle(Theme.Colors.bodyLabel).lineLimit(1).truncationMode(.middle)
                }
            }
            Text("Nothing was merged. \(session.baseBranch) and the spec branch are as they were.")
                .textStyle(Theme.Text.calloutLoose)
                .foregroundStyle(Theme.Colors.bodyLabel)
            if session.isResolving {
                HStack(spacing: Theme.Space.x8) {
                    ProgressView().controlSize(.small)
                    Text(session.activity.last?.text ?? "Claude Code is resolving it…").textStyle(Theme.Text.callout).foregroundStyle(Theme.Colors.bodyLabel).lineLimit(1)
                    Spacer(minLength: 0)
                    Button("Stop") { Task { await session.stop() } }.buttonStyle(BoardPillStyle())
                }
            } else {
                FlowLayout(spacing: Theme.Space.x8) {
                    Button { Task { await session.resolveConflict() } } label: {
                        HStack(spacing: Theme.Space.x6) {
                            Text("Let Claude Code resolve it")
                            Text("about \(TokenStep.text(conflict.tokens)) tokens").fontWeight(.regular).opacity(0.85)
                        }
                    }
                    .buttonStyle(BoardPillStyle(kind: .accent))
                    .disabled(session.isRunning)
                    Button("Open in Terminal", action: session.openMergeInTerminal).buttonStyle(BoardPillStyle())
                    Button("Cancel", action: session.cancelMerge)
                        .buttonStyle(DesignLinkStyle())
                        .padding(.horizontal, Theme.Space.x4)
                        .frame(height: Theme.Size.button)
                }
            }
            Text("Claude Code’s fix comes with a report like a task’s, and you merge after it.")
                .textStyle(Theme.Text.caption)
                .foregroundStyle(Theme.Colors.secondaryLabel)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, Theme.Space.x12)
        .padding(.horizontal, Theme.Space.x14)
        .surface(Theme.Colors.bannerFill, .banner, in: RoundedRectangle(cornerRadius: Theme.Radius.card))
        .accessibilityElement(children: .contain)
    }

    // MARK: Steps

    private func stepSection(_ step: BuildStep, index: Int) -> some View {
        let locked = index > 0 && !spec.isDone(session.steps[index - 1])
        let together = step.kind == .together
        return VStack(alignment: .leading, spacing: Theme.Space.x8) {
            HStack(spacing: Theme.Space.x8) {
                Text("Step \(index + 1)")
                    .textStyle(Theme.Text.stepTitle)
                    .foregroundStyle(locked ? Theme.Colors.secondaryLabel : Theme.Colors.label)
                    .accessibilityAddTraits(.isHeader)
                Text(step.kindWord)
                    .textStyle(Theme.Text.caption)
                    .foregroundStyle(together ? Theme.Colors.likely : Theme.Colors.bodyLabel)
                    .padding(.horizontal, Theme.Space.x8)
                    .frame(height: Theme.Size.stepBadge)
                    .background(together ? Theme.Colors.changedFill : Theme.Colors.badgeFill, in: Capsule())
                Spacer(minLength: 0)
                Text("\(spec.doneCount(step.tasks)) of \(step.tasks.count) done").textStyle(Theme.Text.caption).foregroundStyle(Theme.Colors.secondaryLabel)
            }
            Text(why(step, index: index)).textStyle(Theme.Text.calloutLoose).foregroundStyle(Theme.Colors.bodyLabel)
            if together {
                // As many side by side as get 260 pt each, sharing the width.
                let fits = Int((stepWidth + Theme.Space.x8) / (Theme.Size.taskCardMin + Theme.Space.x8))
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: Theme.Space.x8, alignment: .top), count: max(1, min(step.tasks.count, fits))), spacing: Theme.Space.x8) {
                    ForEach(step.tasks) { card($0) }
                }
                .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { stepWidth = $0 }
            } else {
                VStack(spacing: Theme.Space.x8) {
                    ForEach(step.tasks) { card($0) }
                }
            }
        }
        .padding(Theme.Space.x12)
        .background(Theme.Colors.fill, in: RoundedRectangle(cornerRadius: Theme.Radius.step))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Step \(index + 1)")
    }

    private func why(_ step: BuildStep, index: Int) -> String {
        switch step.kind {
        case .alone:
            return index == 0 && session.steps.count > 1 ? "Every other task builds on it. Run it by itself." : "Run it by itself."
        case .together:
            return "They change different folders, so they won’t clash. Mel runs one at a time; to run them together, copy each prompt into its own terminal."
        case .inOrder:
            let shared = step.tasks.dropFirst().reduce(Set(step.tasks.first?.changes ?? [])) { $0.intersection($1.changes) }.sorted()
            let order = step.tasks.map { "task \($0.number)" }
            return (shared.isEmpty ? "They change the same code." : "They all change \(shared.joined(separator: ", ")).") + " Run \(order.first ?? ""), check it, then " + order.dropFirst().joined(separator: ", then ") + "."
        }
    }

    // MARK: Task card

    @ViewBuilder
    private func card(_ task: SpecTask) -> some View {
        let status = session.checking.contains(task.number) ? .running : session.status(of: task)
        let isChecking = session.checking.contains(task.number)
        let locked: Bool = if case .waiting = status { true } else { false }
        let failed: Bool = if case .failed = status { true } else { false }
        let isNew = session.lastChange?.newTasks.contains(task.number) == true
        VStack(alignment: .leading, spacing: Theme.Space.x8) {
            HStack(spacing: Theme.Space.x8) {
                StatusDot(style: dot(status, isChecking: isChecking))
                Text(isChecking ? "Checking…" : session.runningTask == task.number ? "Running in Mel" : word(status)).textStyle(Theme.Text.caption).foregroundStyle(Theme.Colors.secondaryLabel)
                if isNew {
                    Text("New")
                        .textStyle(Theme.Text.caption)
                        .foregroundStyle(Theme.Colors.likely)
                        .padding(.horizontal, Theme.Space.x6)
                        .frame(height: Theme.Size.newTag)
                        .background(Theme.Colors.changedFill, in: Capsule())
                }
                Spacer(minLength: 0)
                Text("Task \(task.number)").textStyle(Theme.Text.codeCaption).foregroundStyle(Theme.Colors.secondaryLabel)
            }
            Text(task.title.capitalizedFirst)
                .textStyle(Theme.Text.storyTitle)
                .foregroundStyle(locked ? Theme.Colors.secondaryLabel : Theme.Colors.label)
                .fixedSize(horizontal: false, vertical: true)
            if let line = buildsLine(task) {
                Text(line).textStyle(Theme.Text.captionLoose).foregroundStyle(Theme.Colors.secondaryLabel)
            }
            if !task.verify.isEmpty {
                HStack(alignment: .firstTextBaseline, spacing: Theme.Space.x6) {
                    Text("Check").textStyle(Theme.Text.caption).foregroundStyle(Theme.Colors.secondaryLabel)
                    Text(task.verify)
                        .textStyle(Theme.Text.codeCaptionLoose)
                        .foregroundStyle(Theme.Colors.bodyLabel)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.vertical, Theme.Space.x6)
                .padding(.horizontal, Theme.Space.x8)
                .background(Theme.Colors.fill, in: RoundedRectangle(cornerRadius: Theme.Radius.row))
            }
            actions(task, status: status, isChecking: isChecking)
            if copied == task.number, !isChecking {
                Text("Prompt copied. Paste it into Claude Code in \(repo).")
                    .textStyle(Theme.Text.captionLoose)
                    .foregroundStyle(Theme.Colors.success)
                    .accessibilityAddTraits(.updatesFrequently)
            }
            if !locked { promptDisclosure(task, failed: failed) }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Theme.Space.x12)
        .surface(isNew ? Theme.Colors.accentTint : locked ? Theme.Colors.fillSubtle : Theme.Colors.background, isNew ? .taskNew : locked ? .taskWaiting : failed ? .taskFailed : .storyCard, in: RoundedRectangle(cornerRadius: Theme.Radius.card))
        .accessibilityElement(children: .contain)
    }

    private func buildsLine(_ task: SpecTask) -> String? {
        let parts = [task.covers.isEmpty ? nil : "Builds \(task.covers.joined(separator: ", "))",
                     task.changes.isEmpty ? nil : "changes \(task.changes.joined(separator: ", "))"].compactMap { $0 }
        return parts.isEmpty ? nil : parts.joined(separator: " · ").capitalizedFirst
    }

    @ViewBuilder
    private func actions(_ task: SpecTask, status: TaskStatus, isChecking: Bool) -> some View {
        let changed = session.promptChanged(task)
        // V2-12: the check waits while Mel changes the task the request came from.
        let blocked = session.tellingTask == task.number
        if isChecking {
            Text("Mel is running the check on your Mac…").textStyle(Theme.Text.callout).foregroundStyle(Theme.Colors.bodyLabel)
        } else {
            switch status {
            case .waiting(let reason):
                lockedRun(reason)
            case .ready:
                if let other = session.runningTask {
                    lockedRun("Starts after task \(other). Mel runs one task at a time.")
                } else if let (other, _) = asking {
                    lockedRun("Starts after task \(other.number), which waits for your answer.")
                } else {
                    VStack(alignment: .leading, spacing: Theme.Space.x4) {
                        HStack(spacing: Theme.Space.x8) {
                            Button("Run") { Task { await session.run(task) } }
                                .buttonStyle(BoardPillStyle(kind: .accent))
                                .disabled(session.isRunning)
                                .help("Claude Code builds it here on \(session.branch), then Mel runs the check")
                            Button("Copy prompt instead") { copy(task) }
                                .buttonStyle(DesignLinkStyle())
                                .padding(.horizontal, Theme.Space.x4)
                                .frame(height: Theme.Size.button)
                        }
                        Text("Runs with your Claude Code on \(session.branch).").textStyle(Theme.Text.captionLoose).foregroundStyle(Theme.Colors.secondaryLabel).fixedSize(horizontal: false, vertical: true)
                    }
                }
            case .running where session.runningTask == task.number:
                runningInMel(task)
            case .asking:
                Text("Paused on a question about what users will see. Answer it on the right and the task goes on where it stopped.")
                    .textStyle(Theme.Text.calloutLoose)
                    .foregroundStyle(Theme.Colors.label)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, Theme.Space.x8)
                    .padding(.horizontal, Theme.Space.x10)
                    .surface(Theme.Colors.accentTint, .editBanner, in: RoundedRectangle(cornerRadius: Theme.Radius.row))
            case .stopped:
                VStack(alignment: .leading, spacing: Theme.Space.x8) {
                    Text("Stopped. Its changes aren’t committed.").textStyle(Theme.Text.calloutBold).foregroundStyle(Theme.Colors.bannerTitle)
                    Text("Run again goes on from where it stopped, with the changes. Undo puts them aside (a git stash) and the task starts fresh.")
                        .textStyle(Theme.Text.captionLoose)
                        .foregroundStyle(Theme.Colors.bodyLabel)
                        .fixedSize(horizontal: false, vertical: true)
                    FlowLayout(spacing: Theme.Space.x8) {
                        Button("Run again") { Task { await session.run(task) } }
                            .buttonStyle(BoardPillStyle(kind: .accent))
                            .disabled(session.isRunning)
                        Button("Undo them") { Task { await session.undoStopped(task) } }
                            .buttonStyle(BoardPillStyle())
                            .disabled(session.isRunning)
                    }
                }
                .padding(.vertical, Theme.Space.x8)
                .padding(.horizontal, Theme.Space.x10)
                .surface(Theme.Colors.bannerFill, .banner, in: RoundedRectangle(cornerRadius: Theme.Radius.row))
            case .running where session.spec.runs?[task.number]?.report != nil:
                if let report = session.spec.runs?[task.number]?.report { endedWithoutCommit(task, report: report) }
            case .running:
                VStack(alignment: .leading, spacing: Theme.Space.x6) {
                    Text(task.verify.isEmpty ? "Running in Claude Code. When it’s finished, mark it done." : "Running in Claude Code. When it says it’s finished, press Check it.")
                        .textStyle(Theme.Text.callout)
                        .foregroundStyle(Theme.Colors.bodyLabel)
                        .fixedSize(horizontal: false, vertical: true)
                    FlowLayout(spacing: Theme.Space.x8) {
                        if !task.verify.isEmpty {
                            Button("Check it") { check(task) }.buttonStyle(BoardPillStyle(kind: .accent)).disabled(blocked)
                        }
                        Button(changed ? "Prompt changed · Copy again" : "Copy again") { copy(task) }.buttonStyle(BoardPillStyle())
                        Button(task.verify.isEmpty ? "Mark done" : "Mark done without the check") { Task { await session.markDone(task) } }
                            .buttonStyle(DesignLinkStyle())
                            .padding(.horizontal, Theme.Space.x4)
                            .frame(height: Theme.Size.button)
                        tellLink(task)
                    }
                    if blocked, !task.verify.isEmpty { blockedNote("Check it") }
                    if session.uncommitted.contains(task.number) { uncommittedNote(task) }
                }
            case .failed(let output):
                VStack(alignment: .leading, spacing: Theme.Space.x6) {
                    Text("The check failed").textStyle(Theme.Text.calloutBold).foregroundStyle(Theme.Colors.disagreeText)
                    if !output.isEmpty {
                        Text(output).textStyle(Theme.Text.codeCaptionLoose).foregroundStyle(Theme.Colors.bodyLabel).textSelection(.enabled)
                    }
                    FlowLayout(spacing: Theme.Space.x8) {
                        Button("Copy fix prompt") {
                            session.copyFixPrompt(of: task)
                            copied = task.number
                        }
                        .buttonStyle(BoardPillStyle(kind: .accent))
                        Button("Check again") { check(task) }.buttonStyle(BoardPillStyle()).disabled(blocked)
                        tellLink(task)
                    }
                    if changed { promptChangedNote }
                    if blocked { blockedNote("Check again") }
                    if session.uncommitted.contains(task.number) { uncommittedNote(task) }
                }
                .padding(.vertical, Theme.Space.x8)
                .padding(.horizontal, Theme.Space.x10)
                .surface(Theme.Colors.failedFill, .failedOutput, in: RoundedRectangle(cornerRadius: Theme.Radius.row))
            case .done(let run):
                VStack(alignment: .leading, spacing: Theme.Space.x8) {
                    HStack(spacing: Theme.Space.x6) {
                        DesignIcon(glyph: .check, size: Theme.Size.doneCheck).foregroundStyle(Theme.Colors.success)
                        Text(doneText(run, changed: changed))
                            .textStyle(Theme.Text.callout)
                            .foregroundStyle(Theme.Colors.bodyLabel)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        if run.report != nil {
                            Button(shownReports.contains(task.number) ? "Hide report" : "What was done") { toggle(&shownReports, task.number) }
                                .buttonStyle(DesignLinkStyle())
                        }
                        Button("Reopen") { session.reopen(task) }.buttonStyle(DesignLinkStyle())
                    }
                    if let report = run.report, shownReports.contains(task.number) {
                        reportView(report, task: task, tokens: run.tokens).transition(.drop)
                    }
                }
            }
        }
    }

    // MARK: Run in Mel

    /// A task that can't run yet (V2-17): Run is off and says why.
    private func lockedRun(_ reason: String) -> some View {
        HStack(spacing: Theme.Space.x8) {
            HStack(spacing: Theme.Space.x6) {
                DesignIcon(glyph: .lock, size: Theme.Size.removeIcon, weight: 1.8)
                Text("Run")
            }
            .textStyle(Theme.Text.calloutBold)
            .foregroundStyle(Theme.Colors.tertiary)
            .padding(.horizontal, Theme.Space.x12)
            .frame(height: Theme.Size.button)
            .background(Theme.Colors.chipFill, in: Capsule())
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Run, not available")
            Text(reason).textStyle(Theme.Text.captionLoose).foregroundStyle(Theme.Colors.secondaryLabel).fixedSize(horizontal: false, vertical: true)
        }
    }

    /// V2-17: what Claude Code is doing, in plain lines from its tool calls (no tokens spent on narration).
    private func runningInMel(_ task: SpecTask) -> some View {
        let lines = session.activity.map { plain($0.text, verify: task.verify) }
        let all = shownSteps.contains(task.number)
        let shown = all ? lines : Array(lines.suffix(Theme.Size.runLines))
        let files = Set(session.activity.compactMap { line -> String? in
            for verb in ["write ", "edit "] where line.text.hasPrefix(verb) { return String(line.text.dropFirst(verb.count)) }
            return nil
        }).count
        return VStack(alignment: .leading, spacing: Theme.Space.x8) {
            if shown.isEmpty {
                Text("Starting Claude Code…").textStyle(Theme.Text.callout).foregroundStyle(Theme.Colors.bodyLabel)
            }
            ForEach(Array(shown.enumerated()), id: \.offset) { index, line in
                HStack(alignment: .firstTextBaseline, spacing: Theme.Space.x8) {
                    StatusDot(style: index == shown.count - 1 ? .ring(Theme.Colors.accent) : .filled(Theme.Colors.success))
                    Text(line).textStyle(Theme.Text.calloutLoose).foregroundStyle(index == shown.count - 1 ? Theme.Colors.label : Theme.Colors.bodyLabel).lineLimit(2)
                }
            }
            Text("\(files) \(files == 1 ? "file" : "files") changed so far" + ((spec.runs?[task.number]?.tokens).map { " · \(TokenStep.text($0)) tokens" } ?? ""))
                .textStyle(Theme.Text.caption)
                .foregroundStyle(Theme.Colors.secondaryLabel)
            HStack(spacing: Theme.Space.x8) {
                if lines.count > Theme.Size.runLines {
                    Button(all ? "Fewer steps" : "All \(lines.count) steps") { toggle(&shownSteps, task.number) }.buttonStyle(DesignLinkStyle())
                }
                Spacer(minLength: 0)
                Button("Stop") { Task { await session.stop() } }
                    .buttonStyle(BoardPillStyle())
                    .help("Stops Claude Code. Its changes stay, not committed: run it again or undo them.")
            }
        }
        .accessibilityElement(children: .contain)
    }

    /// "write src/a.swift" → "Wrote src/a.swift"; the task's own check reads "Ran the check".
    private func plain(_ step: String, verify: String) -> String {
        let (verb, rest) = step.firstIndex(of: " ").map { (String(step[..<$0]), String(step[step.index(after: $0)...])) } ?? (step, "")
        switch verb {
        case "read": return "Read \(rest)"
        case "write": return "Wrote \(rest)"
        case "edit": return "Changed \(rest)"
        case "list", "search": return "Looked through the code"
        case "run": return rest == verify ? "Ran the check" : rest.hasPrefix("git commit") ? "Committed" : rest.hasPrefix("git add") ? "Staged the changes" : "Ran \(rest)"
        default: return step.capitalizedFirst
        }
    }

    /// V2-19: what a task run in Mel says it did, for someone who doesn't code.
    private func reportView(_ report: BuildReport, task: SpecTask, tokens: Int?) -> some View {
        VStack(alignment: .leading, spacing: Theme.Space.x12) {
            if !report.works.isEmpty {
                reportGroup("What works now") {
                    ForEach(report.works, id: \.self) { Text($0).textStyle(Theme.Text.bodyLoose).fixedSize(horizontal: false, vertical: true) }
                }
            }
            if !report.decisions.isEmpty {
                reportGroup("Decided while building · \(report.decisions.count)") {
                    ForEach(report.decisions, id: \.self) { decision in
                        VStack(alignment: .leading, spacing: Theme.Space.x4) {
                            HStack(alignment: .firstTextBaseline, spacing: Theme.Space.x8) {
                                Text(decision.title).textStyle(Theme.Text.bodyBold).frame(maxWidth: .infinity, alignment: .leading)
                                Button("Change…") {
                                    telling = task
                                    isTelling = true
                                }
                                .buttonStyle(DesignLinkStyle())
                                .help("Tell Mel what you want instead; the request says it came from task \(task.number)")
                            }
                            if !decision.why.isEmpty { Text(decision.why).textStyle(Theme.Text.calloutLoose).foregroundStyle(Theme.Colors.bodyLabel).fixedSize(horizontal: false, vertical: true) }
                            if !decision.instead.isEmpty { Text("Instead: \(decision.instead)").textStyle(Theme.Text.captionLoose).foregroundStyle(Theme.Colors.secondaryLabel).fixedSize(horizontal: false, vertical: true) }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, Theme.Space.x10)
                        .padding(.horizontal, Theme.Space.x12)
                        .background(Theme.Colors.fill, in: RoundedRectangle(cornerRadius: Theme.Radius.box))
                    }
                    Text("Saved in DECISIONS.md with the decisions from planning.").textStyle(Theme.Text.caption).foregroundStyle(Theme.Colors.secondaryLabel)
                }
            }
            if !report.notDone.isEmpty {
                reportGroup("Not done") {
                    ForEach(report.notDone, id: \.self) { Text($0).textStyle(Theme.Text.calloutLoose).fixedSize(horizontal: false, vertical: true) }
                }
            }
            // Mostly the agent's own extra tries; closed unless asked for (real run 2026-11-27).
            if !report.refused.isEmpty {
                let open = shownRefused.contains(task.number)
                Button(open ? "Hide what wasn’t allowed" : "\(report.refused.count) \(report.refused.count == 1 ? "thing" : "things") weren’t allowed") { toggle(&shownRefused, task.number) }
                    .buttonStyle(DesignLinkStyle())
                if open {
                    ForEach(report.refused, id: \.self) { Text($0).textStyle(Theme.Text.captionLoose).foregroundStyle(Theme.Colors.secondaryLabel).fixedSize(horizontal: false, vertical: true) }
                }
            }
            if let tokens {
                Text("Built with \(TokenStep.text(tokens)) tokens.").textStyle(Theme.Text.caption).foregroundStyle(Theme.Colors.secondaryLabel)
            }
        }
    }

    private func reportGroup(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: Theme.Space.x6) {
            Text(title).textStyle(Theme.Text.calloutBold).foregroundStyle(Theme.Colors.bodyLabel).accessibilityAddTraits(.isHeader)
            content()
        }
    }

    private func toggle(_ set: inout Set<Int>, _ number: Int) {
        if set.contains(number) { set.remove(number) } else { set.insert(number) }
    }

    private func doneText(_ run: TaskRun, changed: Bool) -> String {
        let at = run.at.map { " at " + $0.formatted(date: .omitted, time: .shortened) } ?? ""
        if changed { return run.byHand ? "Changed after you marked it done." : "Changed after done. Its check passed\(at) for the old version." }
        let pushed = run.pushed == true ? ", pushed" : ""
        return (run.byHand ? "Marked done by you, no check run" : "Check passed" + at) + pushed
    }

    private func tellLink(_ task: SpecTask) -> some View {
        Button("Tell Mel about this") {
            telling = task
            isTelling = true
        }
            .buttonStyle(DesignLinkStyle())
            .padding(.horizontal, Theme.Space.x4)
            .frame(height: Theme.Size.button)
            .help("Tell Mel what this task turned up; the request says it came from task \(task.number)")
    }

    /// A run in Mel that ended with its report but no commit: usually the plan didn't fit (a folder it
    /// needed isn't in `Changes`). The report's reason, not "No commit", is what the user needs.
    private func endedWithoutCommit(_ task: SpecTask, report: BuildReport) -> some View {
        VStack(alignment: .leading, spacing: Theme.Space.x8) {
            Text("The run ended without a commit").textStyle(Theme.Text.calloutBold).foregroundStyle(Theme.Colors.bannerTitle)
            ForEach(report.notDone, id: \.self) { Text($0).textStyle(Theme.Text.calloutLoose).foregroundStyle(Theme.Colors.bodyLabel).fixedSize(horizontal: false, vertical: true) }
            ForEach(report.refused, id: \.self) { Text("Not allowed: " + $0).textStyle(Theme.Text.captionLoose).foregroundStyle(Theme.Colors.secondaryLabel).fixedSize(horizontal: false, vertical: true) }
            Text("If the plan didn’t fit, tell Mel what to change, then run it again.")
                .textStyle(Theme.Text.captionLoose)
                .foregroundStyle(Theme.Colors.bodyLabel)
                .fixedSize(horizontal: false, vertical: true)
            FlowLayout(spacing: Theme.Space.x8) {
                Button("Run again") { Task { await session.run(task) } }
                    .buttonStyle(BoardPillStyle(kind: .accent))
                    .disabled(session.isRunning || session.tellingTask == task.number)
                if !task.verify.isEmpty {
                    Button("Check it") { check(task) }.buttonStyle(BoardPillStyle())
                }
                tellLink(task)
            }
            if session.uncommitted.contains(task.number) { uncommittedNote(task) }
        }
        .padding(.vertical, Theme.Space.x8)
        .padding(.horizontal, Theme.Space.x10)
        .surface(Theme.Colors.bannerFill, .banner, in: RoundedRectangle(cornerRadius: Theme.Radius.row))
    }

    private func uncommittedNote(_ task: SpecTask) -> some View {
        Text("No commit for task \(task.number) yet. When Claude Code is done it commits with “\(task.trailer(slug: spec.folder.lastPathComponent))”; then Mel can check it.")
            .textStyle(Theme.Text.captionLoose)
            .foregroundStyle(Theme.Colors.cautionText)
            .fixedSize(horizontal: false, vertical: true)
    }

    /// A failed card's buttons are too wide for "Prompt changed · Copy fix prompt" in a narrow column.
    private var promptChangedNote: some View {
        Text("Prompt changed since you copied it. The fix prompt has the new version.")
            .textStyle(Theme.Text.captionLoose)
            .foregroundStyle(Theme.Colors.likely)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func blockedNote(_ button: String) -> some View {
        Text("Mel is updating this task. \(button) opens when it’s done.")
            .textStyle(Theme.Text.captionLoose)
            .foregroundStyle(Theme.Colors.secondaryLabel)
    }

    private func promptDisclosure(_ task: SpecTask, failed: Bool) -> some View {
        let open = shownPrompts.contains(task.number)
        return VStack(alignment: .leading, spacing: Theme.Space.x8) {
            Button {
                if open { shownPrompts.remove(task.number) } else { shownPrompts.insert(task.number) }
            } label: {
                HStack(spacing: Theme.Space.x4) {
                    DesignIcon(glyph: .chevronRight, size: Theme.Size.promptChevron).rotationEffect(.degrees(open ? 90 : 0))
                    Text(open ? "Hide prompt" : failed ? "Show fix prompt" : "Show prompt").textStyle(Theme.Text.callout)
                }
                .foregroundStyle(Theme.Colors.link)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityValue(open ? "Expanded" : "Collapsed")
            if open {
                Text(prompt(task, failed: failed))
                    .textStyle(Theme.Text.codePrompt)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, Theme.Space.x10)
                    .padding(.horizontal, Theme.Space.x12)
                    .background(Theme.Colors.fill, in: RoundedRectangle(cornerRadius: Theme.Radius.row))
            }
        }
    }

    private func prompt(_ task: SpecTask, failed: Bool) -> String {
        let slug = spec.folder.lastPathComponent
        if failed, case .failed(let output) = session.status(of: task) { return task.fixPrompt(slug: slug, of: tasks.count, output: output) }
        return task.buildPrompt(slug: slug, of: tasks.count)
    }

    private func copy(_ task: SpecTask) {
        session.copyPrompt(of: task)
        copied = task.number
    }

    private func check(_ task: SpecTask) {
        copied = nil
        Task { await session.check(task) }
    }

    private func word(_ status: TaskStatus) -> String {
        switch status {
        case .waiting: "Waiting"
        case .ready: "Ready to start"
        case .running: "Running"
        case .failed: "Check failed"
        case .done: "Done"
        case .stopped: "Stopped"
        case .asking: "Needs you"
        }
    }

    private func dot(_ status: TaskStatus, isChecking: Bool) -> StatusDot.Style {
        if isChecking { return .ring(Theme.Colors.accent) }
        switch status {
        case .waiting: return .ring(Theme.Colors.tertiary)
        case .ready: return .filled(Theme.Colors.accent)
        case .running: return .ring(Theme.Colors.accent)
        case .failed: return .filled(Theme.Colors.failure)
        case .done: return .filled(Theme.Colors.success)
        case .stopped: return .filled(Theme.Colors.caution)
        case .asking: return .filled(Theme.Colors.accent)
        }
    }

    // MARK: Tell Mel

    private var tellPanel: some View {
        VStack(alignment: .leading, spacing: Theme.Space.x14) {
            HStack(spacing: Theme.Space.x8) {
                Text("Tell Mel").textStyle(Theme.Text.boardTitle).accessibilityAddTraits(.isHeader)
                Spacer(minLength: 0)
                Button {
                    isTelling = false
                    telling = nil
                    session.dismissChange()
                } label: {
                    DesignIcon(glyph: .close, size: Theme.Size.readyCheck, weight: 2)
                        .foregroundStyle(Theme.Colors.secondaryLabel)
                        .frame(width: Theme.Size.buttonMini, height: Theme.Size.buttonMini)
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .disabled(session.isRunning || spec.unplacedChange != nil)
                .accessibilityLabel("Close")
                .help("Back to How building works")
            }
            Text("What did a task turn up? A missing state, a task to split, a wrong assumption. Mel patches the spec.")
                .textStyle(Theme.Text.calloutLoose)
                .foregroundStyle(Theme.Colors.bodyLabel)
                .fixedSize(horizontal: false, vertical: true)
            BoardTell(session: session, building: true, task: $telling)
                .padding(Theme.Space.x2)
        }
        .padding(Theme.Space.x16)
        .frame(maxHeight: .infinity, alignment: .top)
        
    }

    // MARK: How building works

    /// The task whose run stopped on a question, if any (one runs at a time, so one asks at most).
    private var asking: (SpecTask, BuildQuestion)? {
        for task in tasks { if case .asking(let question) = session.status(of: task) { return (task, question) } }
        return nil
    }

    /// V2-18: the question, in Mel's column, with what each answer means for users.
    private func questionCard(_ task: SpecTask, _ question: BuildQuestion) -> some View {
        let send = { (answer: String) in
            otherAnswer = ""
            answersOther = false
            Task { await session.answer(task, with: answer) }
        }
        return VStack(alignment: .leading, spacing: Theme.Space.x10) {
            Text("Task \(task.number) · \(task.title.capitalizedFirst)").textStyle(Theme.Text.captionBold).foregroundStyle(Theme.Colors.secondaryLabel)
            Text(question.title).textStyle(Theme.Text.cardTitle).fixedSize(horizontal: false, vertical: true)
            if !question.why.isEmpty {
                Text(question.why).textStyle(Theme.Text.calloutLoose).foregroundStyle(Theme.Colors.secondaryLabel).fixedSize(horizontal: false, vertical: true)
            }
            ForEach(Array(question.options.enumerated()), id: \.offset) { index, option in
                Button { send(option.label) } label: {
                    HStack(alignment: .top, spacing: Theme.Space.x10) {
                        Text("\(index + 1)")
                            .textStyle(Theme.Text.caption)
                            .foregroundStyle(Theme.Colors.secondaryLabel)
                            .frame(width: Theme.Size.optionKey, height: Theme.Size.optionKey)
                            .background(Theme.Colors.chipFill, in: RoundedRectangle(cornerRadius: Theme.Radius.progressLarge))
                        VStack(alignment: .leading, spacing: Theme.Space.x2) {
                            Text(option.label).textStyle(Theme.Text.body).foregroundStyle(Theme.Colors.label)
                            if !option.means.isEmpty {
                                Text(option.means).textStyle(Theme.Text.captionLoose).foregroundStyle(Theme.Colors.secondaryLabel)
                            }
                        }
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        if option.suggested {
                            Text("Likely").textStyle(Theme.Text.caption).foregroundStyle(Theme.Colors.likely)
                        }
                    }
                    .padding(.vertical, Theme.Space.x8)
                    .padding(.horizontal, Theme.Space.x10)
                    .frame(minHeight: Theme.Size.optionRow)
                    .surface(Theme.Colors.background, .outlineList, in: RoundedRectangle(cornerRadius: Theme.Radius.box))
                    .contentShape(RoundedRectangle(cornerRadius: Theme.Radius.box))
                }
                .buttonStyle(.plain)
                .keyboardShortcut(KeyEquivalent(Character("\(index + 1)")), modifiers: [])
            }
            if answersOther {
                TextField("Your answer", text: $otherAnswer, axis: .vertical)
                    .textFieldStyle(.plain)
                    .textStyle(Theme.Text.body)
                    .lineLimit(1...4)
                    .padding(Theme.Space.x8)
                    .surface(Theme.Colors.background, .outlineList, in: RoundedRectangle(cornerRadius: Theme.Radius.box))
                    .onSubmit { if !otherAnswer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { send(otherAnswer) } }
                Button("Answer") { send(otherAnswer) }
                    .buttonStyle(BoardPillStyle(kind: .accent))
                    .disabled(otherAnswer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            } else {
                Button("Something else…") { answersOther = true }.buttonStyle(DesignLinkStyle())
            }
            Text("Your answer goes into DECISIONS.md, then task \(task.number) goes on.").textStyle(Theme.Text.caption).foregroundStyle(Theme.Colors.secondaryLabel)
        }
        .disabled(session.isRunning)
        .padding(Theme.Space.x14)
        .surface(Theme.Colors.background, .storyCard, in: RoundedRectangle(cornerRadius: Theme.Radius.card))
    }

    private var aside: some View {
        // Scrolls when a question card and How building works don't fit.
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Space.x14) {
                if let pull = spec.pullRequest { onGitHub(pull) }
                if let (task, question) = asking {
                    Text("Mel needs you · 1").textStyle(Theme.Text.boardTitle).accessibilityAddTraits(.isHeader)
                    questionCard(task, question)
                }
                Text("How building works").textStyle(Theme.Text.boardTitle).accessibilityAddTraits(.isHeader)
                VStack(alignment: .leading, spacing: Theme.Space.x10) {
                    ForEach(Array(Self.how.enumerated()), id: \.offset) { index, text in
                        HStack(alignment: .top, spacing: Theme.Space.x10) {
                            Text("\(index + 1)")
                                .textStyle(Theme.Text.captionBold)
                                .frame(width: Theme.Size.howNumber, height: Theme.Size.howNumber)
                                .surface(Theme.Colors.background, .article, in: Circle())
                            Text(text).textStyle(Theme.Text.calloutLoose).fixedSize(horizontal: false, vertical: true)
                        }
                        .accessibilityElement(children: .combine)
                    }
                }
                VStack(alignment: .leading, spacing: Theme.Space.x6) {
                    Text("Tasks run one at a time").textStyle(Theme.Text.calloutBold)
                    Text("A task opens when the step before it is done and no other task is running. Tasks in one step change different folders, so you can also run them together, each in its own terminal.")
                        .textStyle(Theme.Text.captionLoose)
                        .foregroundStyle(Theme.Colors.secondaryLabel)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.vertical, Theme.Space.x10)
                .padding(.horizontal, Theme.Space.x12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .surface(.clear, .article, in: RoundedRectangle(cornerRadius: Theme.Radius.box))
                VStack(alignment: .leading, spacing: Theme.Space.x6) {
                    Text("Spec files").textStyle(Theme.Text.calloutBold).foregroundStyle(Theme.Colors.bodyLabel)
                    FlowLayout(spacing: Theme.Space.x6) {
                        ForEach(spec.size.files.map(\.fileName) + ["DECISIONS.md"], id: \.self) { name in
                            Button { session.openInEditor(name) } label: {
                                Text(name)
                                    .textStyle(Theme.Text.codeCaption)
                                    .padding(.horizontal, Theme.Space.x8)
                                    .frame(height: Theme.Size.buttonSmall)
                                    .surface(Theme.Colors.background, .fileChip, in: RoundedRectangle(cornerRadius: Theme.Radius.row))
                            }
                            .buttonStyle(.plain)
                            .help("Open \(name) in your editor")
                        }
                    }
                    Text("specs/\(spec.folder.lastPathComponent)").textStyle(Theme.Text.captionLoose).foregroundStyle(Theme.Colors.secondaryLabel)
                }
                Text(defaults).textStyle(Theme.Text.captionTall).foregroundStyle(Theme.Colors.secondaryLabel).fixedSize(horizontal: false, vertical: true)
                Button("Change in Settings") {
                    settingsTab = .specs
                    openSettings()
                }
                .buttonStyle(DesignLinkStyle(text: Theme.Text.captionTall))
                Button("Tell Mel something the plan missed") { isTelling = true }
                    .buttonStyle(BoardPillStyle())
            }
            .padding(Theme.Space.x16)
        }
        .frame(maxHeight: .infinity, alignment: .top)
        
    }

    /// GH-4: the pull request and GitHub's checks, over How building works.
    private func onGitHub(_ pull: PullRequest) -> some View {
        VStack(alignment: .leading, spacing: Theme.Space.x10) {
            Text("On GitHub").textStyle(Theme.Text.boardTitle).accessibilityAddTraits(.isHeader)
            VStack(alignment: .leading, spacing: Theme.Space.x10) {
                HStack(spacing: Theme.Space.x8) {
                    Button("#\(pull.number) \(spec.name)", action: session.openPullRequest)
                        .buttonStyle(.plain)
                        .textStyle(Theme.Text.bodyBold)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .help("Open the pull request on GitHub")
                    Text(pull.merged ? "Merged" : "Open")
                        .textStyle(Theme.Text.captionBold)
                        .foregroundStyle(pull.merged ? Theme.Colors.mergedChipText : Theme.Colors.openChipText)
                        .padding(.horizontal, Theme.Space.x8)
                        .frame(height: Theme.Size.prChip)
                        .background(pull.merged ? Theme.Colors.mergedChipFill : Theme.Colors.openChipFill, in: Capsule())
                }
                Text("\(session.branch) → main · \(tasks.count) \(tasks.count == 1 ? "commit" : "commits")")
                    .textStyle(Theme.Text.codeCaptionLoose)
                    .foregroundStyle(Theme.Colors.secondaryLabel)
                ForEach(session.pullStatus?.checks ?? [], id: \.name) { check in
                    HStack(spacing: Theme.Space.x8) {
                        StatusDot(style: check.outcome == .pending ? .ring(Theme.Colors.accent) : .filled(check.outcome == .passed ? Theme.Colors.success : Theme.Colors.failure))
                        Text(check.name).textStyle(Theme.Text.callout).frame(maxWidth: .infinity, alignment: .leading)
                        Text(check.outcome == .pending ? "running" : check.outcome == .passed ? "passed" : "failed")
                            .textStyle(Theme.Text.caption)
                            .foregroundStyle(Theme.Colors.secondaryLabel)
                    }
                    .accessibilityElement(children: .combine)
                }
            }
            .padding(.vertical, Theme.Space.x12)
            .padding(.horizontal, Theme.Space.x14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .surface(Theme.Colors.background, .storyCard, in: RoundedRectangle(cornerRadius: Theme.Radius.card))
            Text("Through your GitHub CLI. Pushing and merging use no tokens.").textStyle(Theme.Text.caption).foregroundStyle(Theme.Colors.secondaryLabel)
        }
    }

    private static let how = [
        "Run builds a task with your Claude Code, here, on the spec’s own branch. You see what it does as it goes.",
        "It may change only the task’s folders, run its check and commit. When it’s done, Mel runs the check on your Mac.",
        "Passed and committed: the task is Done, its report says what works now and what was decided, and the next ones open. Prefer your terminal? Copy prompt instead, then press Check it.",
    ]

    /// What Start Building did, as Settings › Specs says, and the token total.
    private var defaults: String {
        let did = switch (writesAgentsFile, commitsSpec) {
        case (true, true): "AGENTS.md is written and the spec is committed, so every prompt can point at it."
        case (true, false): "AGENTS.md is written, so every prompt can point at it."
        case (false, true): "The spec is committed."
        case (false, false): "Mel didn’t write AGENTS.md or commit the spec."
        }
        let tokens = showsTokens && spec.tokenTotal > 0 ? " Spec written with \(TokenStep.text(spec.tokenTotal)) tokens; checks run on your Mac and use none." : " Checks run on your Mac and use no tokens."
        return did + tokens
    }
}

extension BuildStep {
    /// The step's badge.
    var kindWord: String {
        switch kind {
        case .alone: "Run alone"
        case .together: "At the same time"
        case .inOrder: "One after the other"
        }
    }
}

#Preview("Start") {
    NavigationStack { BuildView(session: PreviewData.doneSession) }
        .frame(width: 1100, height: 900)
}

#Preview("Midway") {
    NavigationStack { BuildView(session: PreviewData.buildingSession) }
        .frame(width: 1100, height: 900)
}

#Preview("Telling Mel") {
    NavigationStack { BuildView(session: PreviewData.buildingSession, telling: PreviewData.buildingSession.tasks[2]) }
        .frame(width: 1100, height: 900)
}

#Preview("Mel changing files") {
    NavigationStack { BuildView(session: PreviewData.buildTellingSession) }
        .frame(width: 1100, height: 900)
}

#Preview("Change applied") {
    NavigationStack { BuildView(session: PreviewData.buildChangedSession) }
        .frame(width: 1100, height: 900)
}

#Preview("Change unplaced") {
    NavigationStack { BuildView(session: PreviewData.buildUnplacedSession) }
        .frame(width: 1100, height: 900)
}

#Preview("Done") {
    NavigationStack { BuildView(session: PreviewData.builtSession) }
        .frame(width: 1100, height: 900)
}

#Preview("V2-22 Built in Mel, merge into main") {
    NavigationStack { BuildView(session: PreviewData.builtInMelSession) }
        .frame(width: 1100, height: 900)
}

#Preview("V2-23 Merge conflicts") {
    NavigationStack { BuildView(session: PreviewData.mergeConflictSession) }
        .frame(width: 1100, height: 900)
}

#Preview("V2-23 Conflict resolved") {
    NavigationStack { BuildView(session: PreviewData.conflictResolvedSession) }
        .frame(width: 1100, height: 900)
}

#Preview("V2-22 Merged into main") {
    NavigationStack { BuildView(session: PreviewData.mergedLocallySession) }
        .frame(width: 1100, height: 900)
}

#Preview("Pull request, checks running") {
    NavigationStack { BuildView(session: PreviewData.pullRequestChecking) }
        .environment(PreviewData.appState(remotes: PreviewData.remotes))
        .frame(width: 1100, height: 900)
}

#Preview("Pull request, ready") {
    NavigationStack { BuildView(session: PreviewData.pullRequestReady) }
        .frame(width: 1100, height: 900)
}

#Preview("Pull request, a check failed") {
    NavigationStack { BuildView(session: PreviewData.pullRequestFailed) }
        .frame(width: 1100, height: 900)
}

#Preview("Merged") {
    NavigationStack { BuildView(session: PreviewData.pullRequestMerged) }
        .frame(width: 1100, height: 900)
}

#Preview("Push failed") {
    NavigationStack { BuildView(session: PreviewData.pullRequestSession([], pushError: "Couldn’t push to GitHub: Could not resolve host: github.com")) }
        .frame(width: 1100, height: 900)
}

#Preview("Quick fix") {
    NavigationStack { BuildView(session: PreviewData.quickFixDoneSession) }
        .frame(width: 1100, height: 700)
}

#Preview("Task running in Mel") {
    NavigationStack { BuildView(session: PreviewData.buildRunSession) }
        .frame(width: 1036, height: 800)
}

#Preview("Task report") {
    NavigationStack { BuildView(session: PreviewData.buildReportSession, report: 1) }
        .frame(width: 1036, height: 800)
}

#Preview("Task stopped") {
    NavigationStack { BuildView(session: PreviewData.buildStoppedSession) }
        .frame(width: 1036, height: 800)
}

#Preview("Run ended without a commit") {
    NavigationStack { BuildView(session: PreviewData.buildNoCommitSession) }
        .frame(width: 1036, height: 800)
}

#Preview("Changes not committed") {
    NavigationStack { BuildView(session: PreviewData.buildBlockedSession) }
        .frame(width: 1036, height: 800)
}

#Preview("Task asks a question") {
    NavigationStack { BuildView(session: PreviewData.buildQuestionSession) }
        .frame(width: 1036, height: 800)
}
