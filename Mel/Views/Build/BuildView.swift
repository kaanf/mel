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
    /// "Tell Mel about this": the task the next request comes from.
    @State private var telling: SpecTask?
    /// The right panel shows Tell Mel instead of How building works.
    @State private var isTelling: Bool
    /// Width inside an "At the same time" step, for how many cards go side by side.
    @State private var stepWidth = Theme.Size.buildWidth

    private var showsTell: Bool { isTelling || session.isRunning || session.lastChange != nil || spec.unplacedChange != nil }

    init(session: SpecSession, telling: SpecTask? = nil) {
        self.session = session
        _telling = State(initialValue: telling)
        _isTelling = State(initialValue: telling != nil)
    }

    private var spec: Spec { session.spec }
    private var tasks: [SpecTask] { session.tasks }
    private var done: Int { spec.doneCount(tasks) }
    private var allDone: Bool { !tasks.isEmpty && done == tasks.count }
    private var repo: String { spec.project.lastPathComponent }

    var body: some View {
        HStack(spacing: 0) {
            ScrollView {
                    VStack(alignment: .leading, spacing: Theme.Space.x14) {
                        progress
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
            Rectangle().fill(Theme.Colors.separator).frame(width: Theme.Size.hairline)
            Group {
                if showsTell { tellPanel.transition(.opacity) } else { aside.transition(.opacity) }
            }
            .frame(width: Theme.Size.buildAside)
        }
        .foregroundStyle(Theme.Colors.label)
        .background(Theme.Colors.background)
        .animation(.board, value: spec.runs)
        .animation(.board, value: session.checking)
        .animation(.board, value: session.lastChange)
        .animation(.board, value: showsTell)
        .animation(.board, value: session.isRunning)
        .animation(.board, value: spec.unplacedChange)
        .navigationTitle("Build: \(spec.name)")
        .toolbar { toolbar }
    }

    // MARK: Toolbar

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .navigation) {
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
        }
        .sharedBackgroundVisibility(.hidden)
        ToolbarItem(placement: .principal) {
            HStack(spacing: Theme.Space.x8) {
                StatusDot(style: session.isRunning ? .ring(Theme.Colors.accent) : .filled(allDone ? Theme.Colors.success : failedCount > 0 ? Theme.Colors.failure : Theme.Colors.accent))
                Text(pill).textStyle(Theme.Text.callout).foregroundStyle(Theme.Colors.bodyLabel).lineLimit(1)
            }
            .padding(.horizontal, Theme.Space.x12)
            .frame(height: Theme.Size.button)
            .background(Theme.Colors.statusPillFill, in: Capsule())
            .accessibilityElement(children: .combine)
        }
        .sharedBackgroundVisibility(.hidden)
        ToolbarItem {
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
        .sharedBackgroundVisibility(.hidden)
    }

    private var failedCount: Int { tasks.count { if case .failed = session.status(of: $0) { true } else { false } } }
    private var runningCount: Int { tasks.count { session.status(of: $0) == .running } }

    private var pill: String {
        if session.isRunning { return "Mel is changing the files" }
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
        case .ready, .waiting: return Theme.Colors.separator
        }
    }

    // MARK: Built

    private var builtBanner: some View {
        let later = session.stories.filter { !$0.isFirst }
        let byHand = spec.runs?.values.contains { $0.byHand } == true
        return VStack(alignment: .leading, spacing: Theme.Space.x8) {
            Text("The first version is built").textStyle(Theme.Text.boardTitle)
            Text((byHand ? "All \(tasks.count) tasks are done." : "All \(tasks.count) tasks passed their checks.") + " The spec moved to Done."
                 + (later.isEmpty ? "" : " \(later.count) \(later.count == 1 ? "story is" : "stories are") still in Later: \(later.map(\.title).joined(separator: ", ")).")
            )
            .textStyle(Theme.Text.calloutLoose)
            .foregroundStyle(Theme.Colors.bodyLabel)
            HStack(spacing: Theme.Space.x8) {
                if !later.isEmpty {
                    Button("Plan the \(later.count) later \(later.count == 1 ? "story" : "stories")") { session.reopenPlan() }
                        .buttonStyle(BoardPillStyle(kind: .accent))
                }
                Button("Start over", action: session.startOver)
                    .buttonStyle(DesignLinkStyle())
                    .padding(.horizontal, Theme.Space.x4)
                    .frame(height: Theme.Size.button)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, Theme.Space.x14)
        .padding(.horizontal, Theme.Space.x16)
        .surface(Theme.Colors.resultFill, .result, in: RoundedRectangle(cornerRadius: Theme.Radius.card))
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
            let count = step.tasks.count == 2 ? "two" : "\(step.tasks.count)"
            return "Open \(count) Claude Code terminals in this repo and run them all. They change different folders, so they won’t clash."
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
                Text(isChecking ? "Checking…" : word(status)).textStyle(Theme.Text.caption).foregroundStyle(Theme.Colors.secondaryLabel)
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
                Text(reason).textStyle(Theme.Text.callout).foregroundStyle(Theme.Colors.secondaryLabel)
            case .ready:
                HStack(spacing: Theme.Space.x8) {
                    Button("Copy prompt") { copy(task) }.buttonStyle(BoardPillStyle(kind: .accent))
                    Text("Paste it into Claude Code in this repo.").textStyle(Theme.Text.captionLoose).foregroundStyle(Theme.Colors.secondaryLabel)
                }
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
                HStack(spacing: Theme.Space.x6) {
                    DesignIcon(glyph: .check, size: Theme.Size.doneCheck).foregroundStyle(Theme.Colors.success)
                    Text(doneText(run, changed: changed))
                        .textStyle(Theme.Text.callout)
                        .foregroundStyle(Theme.Colors.bodyLabel)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Button("Reopen") { session.reopen(task) }.buttonStyle(DesignLinkStyle())
                }
            }
        }
    }

    private func doneText(_ run: TaskRun, changed: Bool) -> String {
        let at = run.at.map { " at " + $0.formatted(date: .omitted, time: .shortened) } ?? ""
        if changed { return run.byHand ? "Changed after you marked it done." : "Changed after done. Its check passed\(at) for the old version." }
        return run.byHand ? "Marked done by you, no check run" : "Check passed" + at
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
        .background(Theme.Colors.fillSubtle)
    }

    // MARK: How building works

    private var aside: some View {
        VStack(alignment: .leading, spacing: Theme.Space.x14) {
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
                Text("Same step: run them at the same time").textStyle(Theme.Text.calloutBold)
                Text("Mel puts tasks in one step only when they change different folders. Steps go in order: the next one opens when every task in this one is done.")
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
            Spacer(minLength: 0)
        }
        .padding(Theme.Space.x16)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(Theme.Colors.fillSubtle)
    }

    private static let how = [
        "Copy a task’s prompt and paste it into Claude Code, in this repo. The prompt names only the parts of the spec that task needs.",
        "When Claude Code says it’s finished, press Check it. Mel runs the task’s check on your Mac.",
        "Claude Code commits each task with its Mel-Task line. Passed and committed: the task is Done and the next ones open. Failed: copy the fix prompt, it includes the error.",
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

#Preview("Quick fix") {
    NavigationStack { BuildView(session: PreviewData.quickFixDoneSession) }
        .frame(width: 1100, height: 700)
}
