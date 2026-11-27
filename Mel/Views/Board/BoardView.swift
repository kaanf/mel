import SwiftUI
import UniformTypeIdentifiers
import MelSpec

/// V2-2 Board (design/v2 V2-2-Board, with its states V2-4, 5, 7, 8, 9): the whole spec loop on one
/// screen. Center: the plan, or an open file; right: "Mel needs you"; below: Tell Mel.
struct BoardView: View {
    let session: SpecSession
    /// The file open in the center; nil shows the plan. The sidebar's file rows set it too.
    @Binding var openFile: BoardFile?

    @State private var showsFiles = false
    @State private var isEditing = false
    @State private var why = ""
    @AppStorage("showTokens") private var showsTokens = true
    @AppStorage("commitSpec") private var commitsSpec = true
    @AppStorage("writeAgentsFile") private var writesAgentsFile = true

    private var spec: Spec { session.spec }
    private var status: BoardStatus { BoardStatus(spec: spec, isRunning: session.isRunning) }
    private var isAsking: Bool { spec.stage == .discovery }
    private var edited: DocKind? { spec.size.files.first { spec.docs[$0] == .edited } }

    var body: some View {
        VStack(spacing: 0) {
            header
            main
        }
        // The header takes the hidden title bar's place, level with the traffic lights.
        .ignoresSafeArea(.container, edges: .top)
        .background(Theme.Colors.background)
        .navigationTitle(spec.name)
        .inspector(isPresented: .constant(true)) {
            VStack(spacing: 0) {
                inboxHeader
                BoardInbox(session: session) { open(.decisions) }
            }
            .ignoresSafeArea(.container, edges: .top)
            .background(Theme.Colors.fillSubtle)
            .inspectorColumnWidth(Theme.Size.inboxWidth)
        }
        .background { shortcuts }
        .task(id: spec.id) { if isAsking { await session.start() } }
    }

    private var main: some View {
        VStack(alignment: .leading, spacing: 0) {
            if showsFiles {
                BoardFilesStrip(spec: spec, isAsking: isAsking, open: open) { Task { await session.writeNow() } }
                    .padding(EdgeInsets(top: 0, leading: Theme.Space.x20, bottom: Theme.Space.x8, trailing: Theme.Space.x20))
                    .transition(.drop)
            }
            if session.isRunning {
                working
                    .padding(EdgeInsets(top: 0, leading: Theme.Space.x20, bottom: Theme.Space.x10, trailing: Theme.Space.x20))
                    .transition(.drop)
            }
            if spec.halted != nil {
                stoppedBanner
                    .padding(EdgeInsets(top: 0, leading: Theme.Space.x20, bottom: Theme.Space.x10, trailing: Theme.Space.x20))
                    .transition(.drop)
            }
            if let edited {
                editBanner(edited)
                    .padding(EdgeInsets(top: 0, leading: Theme.Space.x20, bottom: Theme.Space.x10, trailing: Theme.Space.x20))
                    .transition(.drop)
            }
            ScrollView {
                center
                    .transition(.opacity)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(EdgeInsets(top: Theme.Space.x4, leading: Theme.Space.x20, bottom: Theme.Space.x16, trailing: Theme.Space.x20))
            }
            // Hidden before there are files, while editing by hand and while the agent is stopped.
            if !isAsking, !isEditing, spec.halted == nil, !spec.written.isEmpty {
                BoardTell(session: session)
                    .frame(maxWidth: Theme.Size.fileMaxWidth)
                    .padding(EdgeInsets(top: 0, leading: Theme.Space.x20, bottom: Theme.Space.x20, trailing: Theme.Space.x20))
                    .transition(.opacity.combined(with: .offset(y: 8)))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .foregroundStyle(Theme.Colors.label)
        // Banners and Tell Mel come and go; the center changes between plan and file.
        .animation(.board, value: session.isRunning)
        .animation(.board, value: spec.halted)
        .animation(.board, value: edited)
        .animation(.board, value: showsFiles)
        .animation(.board, value: openFile)
        .animation(.board, value: isAsking)
        .animation(.board, value: isEditing)
        .animation(.board, value: session.lastChange)
        .animation(.board, value: spec.unplacedChange)
    }

    /// What Mel is doing right now, where the user is looking: which file, and the section it has reached.
    private var working: some View {
        let writing = spec.size.files.first { spec.docs[$0] == .writing }
        return HStack(spacing: Theme.Space.x10) {
            ProgressView().controlSize(.small)
            VStack(alignment: .leading, spacing: Theme.Space.x2) {
                Text(status.text).textStyle(Theme.Text.bodyBold)
                Text(workingNote(writing))
                    .textStyle(Theme.Text.callout)
                    .foregroundStyle(Theme.Colors.bodyLabel)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .contentTransition(.opacity)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if let writing, openFile != .doc(writing) {
                Button("Watch") { open(.doc(writing)) }
                    .buttonStyle(BoardPillStyle())
                    .help("Open \(writing.fileName) and read it as it is written")
            }
            Button("Stop") { Task { await session.stop() } }
                .buttonStyle(BoardPillStyle())
                .help("Stops the agent. Everything written so far is kept.")
        }
        .padding(.vertical, Theme.Space.x10)
        .padding(.horizontal, Theme.Space.x14)
        .surface(Theme.Colors.accentTint, .editBanner, in: RoundedRectangle(cornerRadius: Theme.Radius.card))
        .accessibilityElement(children: .contain)
    }

    private func workingNote(_ writing: DocKind?) -> String {
        if writing != nil { return session.writingSection.map { "Now: \($0)" } ?? session.activity.last?.text.capitalizedFirst ?? "Starting…" }
        if isAsking { return "Its questions appear on the right in a moment." }
        if spec.analyze == .running { return "Looking for places where the files disagree." }
        return "Only the passages that change are rewritten."
    }

    @ViewBuilder
    private var center: some View {
        if let openFile {
            BoardFileView(session: session, file: openFile, isEditing: $isEditing) { close() }
                .frame(maxWidth: Theme.Size.fileMaxWidth, alignment: .leading)
        } else if isAsking {
            BoardAsking(idea: spec.idea, known: session.answeredQuestions.filter { $0.answer != .agentDecides }.compactMap(\.answerText))
                .frame(maxWidth: Theme.Size.askingMaxWidth, alignment: .leading)
        } else {
            BoardPlan(session: session) { open($0) }
        }
    }

    private func open(_ file: BoardFile) {
        if case .doc(let kind) = file, spec.fileState(kind) == .waiting, spec.halted?.file != kind { return }
        isEditing = false
        showsFiles = false
        openFile = file
    }

    private func close() {
        isEditing = false
        openFile = nil
    }

    // MARK: Header

    /// The center's header: the spec's name and size, its status, and its tokens.
    private var header: some View {
        HStack(spacing: Theme.Space.x12) {
            VStack(alignment: .leading, spacing: 0) {
                Text(spec.name).textStyle(Theme.Text.bodyBold).lineLimit(1)
                Text(spec.size.boardLabel).textStyle(Theme.Text.caption).foregroundStyle(Theme.Colors.secondaryLabel).lineLimit(1)
            }
            .layoutPriority(1)
            Spacer(minLength: 0)
            HStack(spacing: Theme.Space.x8) {
                if session.isRunning { ProgressView().controlSize(.mini) } else { status.dot }
                Text(status.text).textStyle(Theme.Text.callout).foregroundStyle(Theme.Colors.bodyLabel).lineLimit(1)
            }
            .padding(.horizontal, Theme.Space.x12)
            .frame(height: Theme.Size.button)
            .background(Theme.Colors.statusPillFill, in: Capsule())
            .accessibilityElement(children: .combine)
            if spec.gate != nil, !session.isRunning {
                Button("Write it now") { Task { await session.writeNow() } }
                    .buttonStyle(DesignLinkStyle())
                    .help("Writes the next file without waiting. Open questions become guesses.")
            }
            if showsTokens, spec.tokenTotal > 0 { TokenReadout(spec: spec) }
        }
        .padding(.horizontal, Theme.Space.x20)
        .frame(height: Theme.Size.columnHeader)
    }

    /// Over the inbox: Files and Start Building.
    private var inboxHeader: some View {
        HStack(spacing: Theme.Space.x8) {
            Spacer(minLength: 0)
            Button { showsFiles.toggle() } label: {
                HStack(spacing: Theme.Space.x6) {
                    DesignIcon(glyph: .file, size: Theme.Size.paperclipIcon)
                    Text("Files")
                }
            }
            .buttonStyle(BoardPillStyle())
            .accessibilityValue(showsFiles ? "Shown" : "Hidden")
            .help("The spec's Markdown files and their state")
            Button("Start Building") {
                Task {
                    do { try await session.startBuilding(commitToGit: commitsSpec && session.canCommit, writeAgentsFile: writesAgentsFile) } catch {}
                }
            }
            .buttonStyle(DesignButtonStyle(height: Theme.Size.button, leading: Theme.Space.x14, trailing: Theme.Space.x14))
            .disabled(!spec.isReady || session.isRunning)
        }
        .padding(.horizontal, Theme.Space.x16)
        .frame(height: Theme.Size.columnHeader)
    }

    /// ⌘1 to ⌘5 open the files in order; Esc goes back to the plan.
    private var shortcuts: some View {
        ZStack {
            ForEach(Array(spec.size.files.enumerated()), id: \.element) { index, kind in
                Button("") { open(.doc(kind)) }.keyboardShortcut(KeyEquivalent(Character("\(index + 1)")), modifiers: .command)
            }
            if openFile != nil, !isEditing {
                Button("") { close() }.keyboardShortcut(.cancelAction)
            }
        }
        .opacity(0)
        .accessibilityHidden(true)
    }

    // MARK: Banners

    /// V2-5: the agent stopped. Finished files and answers are untouched.
    private var stoppedBanner: some View {
        let halt = spec.halted
        let paused = halt?.reason == .user
        let finished = spec.written.count
        return VStack(alignment: .leading, spacing: Theme.Space.x8) {
            Text(paused ? "Paused" + (halt?.file.map { " while writing \($0.fileName)" } ?? "") : "Claude Code stopped" + (halt?.file.map { " while writing \($0.fileName)" } ?? ""))
                .textStyle(Theme.Text.bodyBold)
                .foregroundStyle(Theme.Colors.bannerTitle)
            Text((paused ? "Mel stopped where you left it." : session.lastError ?? session.haltText ?? "")
                 + " Your answers and the \(finished) finished \(finished == 1 ? "file" : "files") are safe"
                 + (halt?.file.map { "; \($0.fileName) is saved as far as it got." } ?? "."))
                .textStyle(Theme.Text.calloutLoose)
                .foregroundStyle(Theme.Colors.bodyLabel)
            HStack(spacing: Theme.Space.x8) {
                Button("Resume") { Task { await session.resumeBoard() } }
                    .buttonStyle(BoardPillStyle(kind: .accent))
                if let file = halt?.file {
                    Button("Finish it myself") {
                        session.finishBoardByHand()
                        open(.doc(file))
                    }
                    .buttonStyle(DesignLinkStyle())
                    .frame(height: Theme.Size.button)
                }
            }
            .disabled(session.isRunning)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, Theme.Space.x12)
        .padding(.horizontal, Theme.Space.x14)
        .surface(Theme.Colors.bannerFill, .banner, in: RoundedRectangle(cornerRadius: Theme.Radius.card))
        .accessibilityElement(children: .contain)
    }

    /// Edit after it's written (was C1): which files were built on the edit, Update or Keep, and a reason for DECISIONS.md.
    private func editBanner(_ kind: DocKind) -> some View {
        let built = spec.builtOnEdit
        let down = built.isEmpty ? "Nothing else was built on it."
            : built.count == 1 ? "\(built[0].fileName) was built on it."
            : "\(built.count) files were built on it: \(built.map(\.fileName).joined(separator: ", "))."
        return VStack(alignment: .leading, spacing: Theme.Space.x8) {
            Text("You changed \(kind.fileName). \(down)").textStyle(Theme.Text.bodyBold)
            Text("Update rewrites only the parts that depend on your change. Anything that needs your call comes back as a question on the right.")
                .textStyle(Theme.Text.calloutLoose)
                .foregroundStyle(Theme.Colors.bodyLabel)
            Text("Why did you change it? Saved to DECISIONS.md so agents know.")
                .textStyle(Theme.Text.captionBold)
                .foregroundStyle(Theme.Colors.bodyLabel)
            TextField("For example: studio policy changed", text: $why)
                .textFieldStyle(.plain)
                .textStyle(Theme.Text.body)
                .padding(.horizontal, Theme.Space.x10)
                .frame(height: Theme.Size.chip)
                .surface(Theme.Colors.background, .outlineStrong, in: RoundedRectangle(cornerRadius: Theme.Radius.row))
                .accessibilityLabel("Why did you change it?")
            HStack(spacing: Theme.Space.x8) {
                if built.isEmpty {
                    Button("Done") { settle { await session.keepEdit(why: $0) } }.buttonStyle(BoardPillStyle(kind: .accent))
                } else {
                    Button(built.count == 1 ? "Update \(built[0].fileName)" : "Update \(built.count) files") { settle { await session.updateAfterEdit(why: $0) } }
                        .buttonStyle(BoardPillStyle(kind: .accent))
                    Button("Keep them as they are") { settle { await session.keepEdit(why: $0) } }.buttonStyle(BoardPillStyle())
                }
                Button("Undo my change") { settle { _ in await session.undoBoardEdit() } }
                    .buttonStyle(DesignLinkStyle())
                    .frame(height: Theme.Size.button)
            }
            .disabled(session.isRunning)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, Theme.Space.x12)
        .padding(.horizontal, Theme.Space.x14)
        .surface(Theme.Colors.accentTint, .editBanner, in: RoundedRectangle(cornerRadius: Theme.Radius.card))
    }

    private func settle(_ action: @escaping (String) async -> Void) {
        let reason = why.trimmingCharacters(in: .whitespacesAndNewlines)
        why = ""
        Task { await action(reason) }
    }
}

/// A file the board's center can show: one of the spec's files, or the decision log.
enum BoardFile: Hashable {
    case doc(DocKind)
    case decisions

    var name: String {
        switch self {
        case .doc(let kind): kind.fileName
        case .decisions: "DECISIONS.md"
        }
    }
}

/// The toolbar pill: one line on what the board is doing or waiting for.
struct BoardStatus {
    let spec: Spec
    let isRunning: Bool

    var text: String {
        if let halt = spec.halted {
            return switch halt.reason {
            case .user: "Paused"
            case .usageLimit: "Stopped · usage limit"
            case .signedOut: "Stopped · signed out"
            default: "Stopped"
            }
        }
        if spec.stage == .discovery { return isRunning ? "Reading your idea" : "Waiting for your answer" }
        if spec.unplacedChange != nil { return isRunning ? "Rewriting \(spec.unplacedChange?.files.first?.fileName ?? "")" : "Waiting: rewrite or cancel?" }
        if let writing = spec.size.files.first(where: { spec.docs[$0] == .writing }) { return "Writing \(writing.fileName)" }
        if spec.analyze == .running { return "Checking the files" }
        if isRunning { return "Placing your change…" }
        if spec.docs.values.contains(.edited) { return "Waiting: update or keep?" }
        if spec.isReady { return "Plan is ready" }
        if let gate = spec.gate { return "\(gate.file.fileName) starts after \(Self.answers(gate.answers))" }
        let open = spec.openCards.count
        return open > 0 ? "Waiting for \(Self.answers(open))" : "Waiting"
    }

    @ViewBuilder var dot: some View {
        if spec.halted != nil {
            StatusDot(style: .filled(Theme.Colors.caution))
        } else if spec.isReady {
            StatusDot(style: .filled(Theme.Colors.success))
        } else if spec.gate != nil, !isRunning {
            StatusDot(style: .ring(Theme.Colors.tertiary))
        } else {
            StatusDot(style: .filled(Theme.Colors.accent))
        }
    }

    static func answers(_ count: Int) -> String { "\(count) \(count == 1 ? "answer" : "answers")" }
}

extension SpecSize {
    /// The chip next to the spec's name.
    var boardLabel: String {
        switch self {
        case .quickFix: "Quick fix"
        case .feature: "Feature"
        case .product: "New product"
        }
    }
}

extension FileState {
    var word: String {
        switch self {
        case .ready: "Ready"
        case .writing: "Writing"
        case .needsYou: "Needs you"
        case .waiting: "Waiting"
        }
    }
}

/// The 7 pt file state dot: Ready green, Writing blue ring, Needs you blue, Waiting grey ring.
struct FileStateDot: View {
    let state: FileState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Group {
            switch state {
            case .ready: Circle().fill(Theme.Colors.success)
            case .needsYou: Circle().fill(Theme.Colors.accent)
            case .writing:
                // Pulses while the file is written, so the row reads as alive at a glance.
                Circle().strokeBorder(Theme.Colors.accent, lineWidth: Theme.Size.statusDotStroke)
                    .phaseAnimator(reduceMotion ? [false] : [false, true]) { dot, dim in
                        dot.opacity(dim ? 0.35 : 1)
                    } animation: { _ in .easeInOut(duration: 0.7) }
            case .waiting: Circle().strokeBorder(Theme.Colors.tertiary, lineWidth: Theme.Size.statusDotStroke)
            }
        }
        .frame(width: Theme.Size.fileDot, height: Theme.Size.fileDot)
        .accessibilityHidden(true)
    }
}

/// 28 pt pills of the board: accent, white with a hairline, red (Remove), or grey (back to Plan, view buttons).
struct BoardPillStyle: ButtonStyle {
    enum Kind { case accent, white, destructive, quiet }

    var kind: Kind = .white
    var height: CGFloat = Theme.Size.button
    var padding: CGFloat = Theme.Space.x12
    var elevation: Theme.Elevation = .pill
    /// 11/14 on the 24 pt Copy buttons; otherwise 12/16, semibold on a filled pill.
    var text: Theme.TextStyle?

    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .textStyle(text ?? (kind == .accent || kind == .destructive ? Theme.Text.calloutBold : Theme.Text.callout))
            .foregroundStyle(kind == .accent || kind == .destructive ? Theme.Colors.onAccent : Theme.Colors.label)
            .padding(.horizontal, padding)
            .frame(height: height)
            .surface(fill, kind == .white ? elevation : .init(), in: Capsule())
            .opacity(configuration.isPressed ? 0.85 : 1)
            .contentShape(Capsule())
    }

    private var fill: Color {
        switch kind {
        case .accent: isEnabled ? Theme.Colors.accent : Theme.Colors.tertiary
        case .destructive: Theme.Colors.failure
        case .white: Theme.Colors.background
        case .quiet: Theme.Colors.chipFill
        }
    }
}

/// Files (V2-9): the spec's files with their state. Clicking one opens it in the center.
struct BoardFilesStrip: View {
    let spec: Spec
    let isAsking: Bool
    let open: (BoardFile) -> Void
    let writeNow: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.x8) {
            HStack(alignment: .firstTextBaseline, spacing: Theme.Space.x8) {
                Text(isAsking
                     ? "Mel writes these after your answers, one at a time. You don’t have to read them; the plan is their summary."
                     : "Written one at a time: the next file starts when the questions about the one before are answered. You don’t have to read them; the plan is their summary.")
                    .textStyle(Theme.Text.callout)
                    .foregroundStyle(Theme.Colors.bodyLabel)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if spec.gate != nil {
                    Button("Write it now", action: writeNow).buttonStyle(DesignLinkStyle())
                }
                Text("⌘1 to ⌘\(spec.size.files.count) open a file · Esc goes back")
                    .textStyle(Theme.Text.caption)
                    .foregroundStyle(Theme.Colors.secondaryLabel)
            }
            FlowLayout(spacing: Theme.Space.x6) {
                ForEach(spec.size.files, id: \.self) { kind in
                    let state = spec.fileState(kind)
                    Button { open(.doc(kind)) } label: {
                        HStack(spacing: Theme.Space.x6) {
                            Text(kind.fileName).textStyle(Theme.Text.codeCaption)
                            FileStateDot(state: state)
                            Text(spec.gate?.file == kind ? "Starts after \(BoardStatus.answers(spec.gate?.answers ?? 0))" : state.word)
                                .textStyle(Theme.Text.caption)
                                .foregroundStyle(Theme.Colors.secondaryLabel)
                        }
                        .foregroundStyle(Theme.Colors.label)
                        .padding(.horizontal, Theme.Space.x10)
                        .frame(height: Theme.Size.chip)
                        .surface(Theme.Colors.background, .fileChip, in: RoundedRectangle(cornerRadius: Theme.Radius.row))
                    }
                    .buttonStyle(.plain)
                }
                Button { open(.decisions) } label: {
                    Text("DECISIONS.md")
                        .textStyle(Theme.Text.codeCaption)
                        .foregroundStyle(Theme.Colors.label)
                        .padding(.horizontal, Theme.Space.x10)
                        .frame(height: Theme.Size.chip)
                        .surface(Theme.Colors.background, .fileChip, in: RoundedRectangle(cornerRadius: Theme.Radius.row))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, Theme.Space.x10)
        .padding(.horizontal, Theme.Space.x12)
        .background(Theme.Colors.fill, in: RoundedRectangle(cornerRadius: Theme.Radius.card))
    }
}

/// Before the plan exists: the idea, what Mel understands so far, and where the plan will appear.
struct BoardAsking: View {
    let idea: String
    let known: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.x16) {
            VStack(alignment: .leading, spacing: Theme.Space.x6) {
                Text("Your idea").textStyle(Theme.Text.captionBold).foregroundStyle(Theme.Colors.secondaryLabel)
                Text(idea).textStyle(Theme.Text.intro)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, Theme.Space.x14)
            .padding(.horizontal, Theme.Space.x16)
            .background(Theme.Colors.fill, in: RoundedRectangle(cornerRadius: Theme.Radius.card))
            if !known.isEmpty {
                VStack(alignment: .leading, spacing: Theme.Space.x8) {
                    Text("Mel understands so far").textStyle(Theme.Text.calloutBold).foregroundStyle(Theme.Colors.bodyLabel)
                    FlowLayout(spacing: Theme.Space.x6) {
                        ForEach(known, id: \.self) { label in
                            HStack(spacing: Theme.Space.x6) {
                                DesignIcon(glyph: .check, size: Theme.Size.readyCheck + 1, weight: 2.2).foregroundStyle(Theme.Colors.success)
                                Text(label).textStyle(Theme.Text.callout).fixedSize(horizontal: false, vertical: true)
                            }
                            .padding(.vertical, Theme.Space.x5)
                            .padding(.horizontal, Theme.Space.x10)
                            .frame(minHeight: Theme.Size.buttonSmall)
                            .background(Theme.Colors.chipFill, in: RoundedRectangle(cornerRadius: Theme.Size.buttonSmall / 2))
                            .transition(.opacity.combined(with: .scale(scale: 0.9)))
                        }
                    }
                }
            }
            BoardSkeleton().padding(.top, Theme.Space.x8)
            Text("The plan appears here after your answers. Mel writes the files one at a time.")
                .textStyle(Theme.Text.callout)
                .foregroundStyle(Theme.Colors.secondaryLabel)
        }
    }
}

/// Grey placeholder for a plan that isn't written yet.
struct BoardSkeleton: View {
    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.x10) {
            GeometryReader { proxy in
                Capsule().fill(Theme.Colors.skeleton).frame(width: proxy.size.width * 0.3)
            }
            .frame(height: Theme.Size.skeletonLine)
            ForEach(0..<3, id: \.self) { _ in
                RoundedRectangle(cornerRadius: Theme.Radius.card).fill(Theme.Colors.statusPillFill).frame(height: Theme.Size.skeletonCard)
            }
        }
        .accessibilityHidden(true)
    }
}

#Preview("Board, cards") {
    NavigationStack { BoardView(session: PreviewData.boardSession, openFile: .constant(nil)) }
        .frame(width: 1036, height: 800)
}

#Preview("Asking") {
    NavigationStack { BoardView(session: PreviewData.boardAskingSession, openFile: .constant(nil)) }
        .frame(width: 1036, height: 800)
}

#Preview("Waiting for answers") {
    NavigationStack { BoardView(session: PreviewData.boardWaitingSession, openFile: .constant(nil)) }
        .frame(width: 1036, height: 800)
}

#Preview("Writing a file") {
    NavigationStack { BoardView(session: PreviewData.boardWritingSession, openFile: .constant(nil)) }
        .frame(width: 1036, height: 800)
}

#Preview("Stopped") {
    NavigationStack { BoardView(session: PreviewData.boardStoppedSession, openFile: .constant(nil)) }
        .frame(width: 1036, height: 800)
}

#Preview("Change couldn't be placed") {
    NavigationStack { BoardView(session: PreviewData.boardUnplacedSession, openFile: .constant(nil)) }
        .frame(width: 1036, height: 800)
}

#Preview("Change applied") {
    NavigationStack { BoardView(session: PreviewData.boardChangedSession, openFile: .constant(nil)) }
        .frame(width: 1036, height: 800)
}

#Preview("Edited by hand") {
    NavigationStack { BoardView(session: PreviewData.boardEditedSession, openFile: .constant(nil)) }
        .frame(width: 1036, height: 800)
}

extension String {
    /// "builds 1.1" → "Builds 1.1".
    var capitalizedFirst: String { prefix(1).uppercased() + dropFirst() }
}
