import SwiftUI
import UniformTypeIdentifiers
import MelSpec

/// Tell Mel in Mel's column (V2-2, V2-24): the last change's result line and the one-line bar that
/// opens the panel (⌘K). On Build the same bar sits under How building works.
struct TellBar: View {
    let session: SpecSession
    var building = false
    let open: () -> Void
    let review: () -> Void

    private var spec: Spec { session.spec }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.x10) {
            if let change = session.lastChange { result(change).transition(.drop) }
            Button(action: open) {
                HStack(spacing: Theme.Space.x10) {
                    MelMark(size: Theme.Size.markSmall)
                    let draft = session.tellDraft.trimmingCharacters(in: .whitespacesAndNewlines)
                    Text(draft.isEmpty ? (building ? "Tell Mel what a task turned up…" : "Tell Mel what to change, add or remove…") : draft)
                        .textStyle(Theme.Text.body)
                        .foregroundStyle(draft.isEmpty ? Theme.Colors.secondaryLabel : Theme.Colors.label)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    KeyHint("⌘K")
                }
                .padding(.leading, Theme.Space.x12)
                .padding(.trailing, Theme.Space.x10)
                .frame(height: Theme.Size.tellBar)
                .surface(Theme.Colors.background, .tellBar, in: RoundedRectangle(cornerRadius: Theme.Radius.card))
                .contentShape(RoundedRectangle(cornerRadius: Theme.Radius.card))
            }
            .buttonStyle(.plain)
            .keyboardShortcut("k", modifiers: .command)
            .accessibilityLabel("Tell Mel")
            .accessibilityHint("Opens the Tell Mel panel")
        }
        .animation(.board, value: session.lastChange)
    }

    private func result(_ change: SpecSession.ChangeResult) -> some View {
        VStack(alignment: .leading, spacing: Theme.Space.x10) {
            HStack(alignment: .top, spacing: Theme.Space.x10) {
                DoneMark(size: 18).padding(.top, 1)
                VStack(alignment: .leading, spacing: Theme.Space.x2) {
                    Text(TellPanel.line(change)).textStyle(Theme.Text.bodyBold).fixedSize(horizontal: false, vertical: true)
                    Text(TellPanel.note(change, highlighted: true))
                        .textStyle(Theme.Text.captionLoose)
                        .foregroundStyle(Theme.Colors.secondaryLabel)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Button { session.dismissChange() } label: {
                    DesignIcon(glyph: .close, size: 9, weight: 2.2)
                        .foregroundStyle(Theme.Colors.secondaryLabel)
                        .frame(width: 22, height: 22)
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Dismiss")
            }
            HStack(spacing: Theme.Space.x6) {
                if !change.edits.isEmpty || change.line.hasPrefix("Rewrote") {
                    Button("Review changes", action: review)
                        .buttonStyle(BoardPillStyle(kind: .quiet, height: 26, padding: Theme.Space.x10, text: Theme.Text.calloutMedium))
                }
                Button("Undo") { session.undoChange() }
                    .buttonStyle(DesignLinkStyle())
                    .padding(.horizontal, Theme.Space.x8)
                    .frame(height: 26)
                    .disabled(session.isRunning)
            }
            .padding(.leading, 28)
        }
        .padding(Theme.Space.x12)
        .surface(Theme.Colors.background, .tellResult, in: RoundedRectangle(cornerRadius: Theme.Radius.card))
        .accessibilityElement(children: .contain)
    }
}

/// A key hint chip: "⌘K", "esc".
struct KeyHint: View {
    let text: String
    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text)
            .textStyle(Theme.Text.caption)
            .foregroundStyle(Theme.Colors.secondaryLabel)
            .padding(.horizontal, Theme.Space.x6)
            .frame(height: Theme.Size.keyHintChip)
            .surface(Theme.Colors.keycap, .keycap, in: RoundedRectangle(cornerRadius: 5))
            .accessibilityHidden(true)
    }
}

/// The green check in a disc: an answered question, a done step, an applied change.
struct DoneMark: View {
    var size: CGFloat = 16

    var body: some View {
        ZStack {
            Circle().fill(Theme.Colors.success)
            DesignIcon(glyph: .check, size: size * 0.6, weight: 2.2).foregroundStyle(Theme.Colors.onAccent)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

/// The Tell Mel panel (V2-24 to V2-27), a sheet over the board or Build: write the change, watch Mel
/// place it, review what changed (already applied; Undo this per change), or choose how to go on when
/// it couldn't be placed. One request at a time; no chat, no history.
struct TellPanel: View {
    let session: SpecSession
    var building = false
    /// Build: "Tell Mel about this" on a task puts the task here.
    @Binding var task: SpecTask?
    /// Where: the file open in the center, preselected.
    var openFile: DocKind?
    /// Review › Open: shows the file in the center.
    var show: (DocKind) -> Void = { _ in }
    @Binding var reviewing: Bool
    let close: () -> Void

    @State private var scope: DocKind?
    @State private var isAttaching = false
    @FocusState private var isFocused: Bool

    private var spec: Spec { session.spec }
    private var request: String { session.tellDraft.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var canSend: Bool { !request.isEmpty && !session.isRunning && spec.unplacedChange == nil }

    private enum Phase { case compose, working, review, unplaced }

    private var phase: Phase {
        if session.rewriting != nil || (session.isRunning && session.telling != nil) { return .working }
        if spec.unplacedChange != nil { return .unplaced }
        if reviewing, session.lastChange != nil { return .review }
        return .compose
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            switch phase {
            case .compose: compose
            case .working: working
            case .review: review
            case .unplaced: unplaced
            }
        }
        .frame(width: Theme.Size.tellPanelWidth)
        .frame(maxHeight: Theme.Size.tellPanelHeight)
        .background(Theme.Colors.background)
        .foregroundStyle(Theme.Colors.label)
        .animation(.board, value: phase)
        .onAppear {
            scope = openFile.flatMap { spec.written.contains($0) ? $0 : nil }
            isFocused = true
        }
        .fileImporter(isPresented: $isAttaching, allowedContentTypes: [.item], allowsMultipleSelection: true) { result in
            if case .success(let urls) = result { session.tellFiles += urls.filter { !session.tellFiles.contains($0) } }
        }
    }

    // MARK: Header

    private var title: String {
        switch phase {
        case .compose: return "Tell Mel"
        case .working: return session.rewriting.map { "Rewriting \($0.fileName)…" } ?? "Placing your change…"
        case .review: return session.lastChange.map(Self.reviewTitle) ?? ""
        case .unplaced: return "Mel couldn’t find one place for this"
        }
    }

    private var subtitle: String {
        switch phase {
        case .compose: return building ? "What did a task turn up? Mel patches the spec; prompts you already ran are marked." : "One change at a time, against the current files. Mel edits only the passages it touches."
        case .working: return session.rewriting != nil ? "You chose a full rewrite. The other files stay as they are." : "Mel reads the files once and edits only what it needs."
        case .review: return session.lastChange?.edits.isEmpty == false ? "Already in your files and highlighted. Undo any of them here." : "Already in the file."
        case .unplaced: return "Your words are kept. Choose how to go on."
        }
    }

    private var header: some View {
        HStack(spacing: Theme.Space.x12) {
            MelMark(size: Theme.Size.markPanel)
            VStack(alignment: .leading, spacing: 1) {
                Text(title).textStyle(Theme.Text.headline).accessibilityAddTraits(.isHeader)
                Text(subtitle).textStyle(Theme.Text.callout).foregroundStyle(Theme.Colors.secondaryLabel).fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if phase != .working {
                KeyHint("esc")
                Button(action: finish) {
                    DesignIcon(glyph: .close, size: 10, weight: 2.2)
                        .foregroundStyle(Theme.Colors.bodyLabel)
                        .frame(width: 28, height: 28)
                        .background(Theme.Colors.chipFill, in: Circle())
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.cancelAction)
                .accessibilityLabel("Close")
            }
        }
        .padding(EdgeInsets(top: 18, leading: Theme.Space.x20, bottom: Theme.Space.x14, trailing: Theme.Space.x16))
    }

    /// Closing: Review keeps the changes (all undone counts as Undo all); Couldn't be placed hands the words back.
    private func finish() {
        switch phase {
        case .review:
            if let change = session.lastChange, !change.edits.isEmpty, change.reverted.count == change.edits.count { session.undoChange() }
            reviewing = false
        case .unplaced:
            Task { session.tellDraft = await session.cancelUnplaced() }
        case .compose, .working:
            break
        }
        close()
    }

    // MARK: Compose (V2-24)

    private var compose: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    if let task { chip(task).padding(EdgeInsets(top: 0, leading: Theme.Space.x20, bottom: Theme.Space.x10, trailing: Theme.Space.x20)) }
                    scopes.padding(EdgeInsets(top: 0, leading: Theme.Space.x20, bottom: Theme.Space.x12, trailing: Theme.Space.x20))
                    composer.padding(.horizontal, Theme.Space.x20)
                    if let error = session.lastError {
                        Text(error + " Nothing was changed; your words are still here.")
                            .textStyle(Theme.Text.captionLoose)
                            .foregroundStyle(Theme.Colors.cautionText)
                            .padding(EdgeInsets(top: Theme.Space.x8, leading: Theme.Space.x20, bottom: 0, trailing: Theme.Space.x20))
                    }
                    if request.isEmpty { examples.padding(EdgeInsets(top: Theme.Space.x16, leading: Theme.Space.x20, bottom: 0, trailing: Theme.Space.x20)) }
                }
                .padding(.bottom, Theme.Space.x12)
            }
            footer {
                Button { isAttaching = true } label: {
                    HStack(spacing: Theme.Space.x6) {
                        DesignIcon(glyph: .attach, size: 13)
                        Text("Attach")
                    }
                }
                .buttonStyle(PanelButtonStyle())
                Button {
                    isFocused = true
                    session.dictate()
                } label: {
                    Image(systemName: "mic").font(.system(size: 13, weight: .medium)).frame(width: 18)
                }
                .buttonStyle(PanelButtonStyle(square: true))
                .accessibilityLabel("Dictate")
                .help("Say it instead of typing; the words land in the box")
                Text(hint)
                    .textStyle(Theme.Text.captionLoose)
                    .foregroundStyle(Theme.Colors.secondaryLabel)
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .padding(.horizontal, Theme.Space.x6)
                Button(action: send) {
                    HStack(spacing: Theme.Space.x8) {
                        Text("Send to Mel")
                        Text("⌘↩").textStyle(Theme.Text.captionMedium).padding(.horizontal, 5).frame(height: 18)
                            .background(Theme.Colors.keyHintOnAccent, in: RoundedRectangle(cornerRadius: Theme.Radius.keyHint))
                    }
                }
                .buttonStyle(PanelButtonStyle(primary: true))
                .disabled(!canSend)
                .keyboardShortcut(.return, modifiers: .command)
            }
        }
    }

    private var hint: String {
        guard !request.isEmpty else { return "Long text and files are fine." }
        return scope.map { "Only in \($0.fileName) · about 1k tokens" } ?? "Mel finds the passages · about 1 to 2k tokens"
    }

    private var scopes: some View {
        FlowLayout(spacing: Theme.Space.x6) {
            Text("Where").textStyle(Theme.Text.callout).foregroundStyle(Theme.Colors.secondaryLabel).frame(height: Theme.Size.scopeChip).padding(.trailing, Theme.Space.x4)
            scopeChip("Let Mel decide", on: scope == nil, mono: false) { scope = nil }
            ForEach(spec.written, id: \.self) { kind in
                scopeChip(kind.fileName, on: scope == kind, mono: true) { scope = kind }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Where it applies")
    }

    private func scopeChip(_ label: String, on: Bool, mono: Bool, pick: @escaping () -> Void) -> some View {
        Button(action: pick) {
            Text(label)
                .textStyle(mono ? Theme.Text.codeCaption : Theme.Text.callout)
                .foregroundStyle(on ? Theme.Colors.chipSelectedText : Theme.Colors.label)
                .padding(.horizontal, Theme.Space.x10)
                .frame(height: Theme.Size.scopeChip)
                .background(on ? Theme.Colors.chipSelected : Theme.Colors.chipFill, in: Capsule())
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(on ? .isSelected : [])
    }

    private var composer: some View {
        VStack(alignment: .leading, spacing: Theme.Space.x12) {
            TextField("Say what to change, add or remove, in your own words.", text: Bindable(session).tellDraft, axis: .vertical)
                .lineLimit(5...12)
                .textFieldStyle(.plain)
                .textStyle(Theme.Text.tellComposer)
                .focused($isFocused)
                .accessibilityLabel("Your change, in your own words")
            if !session.tellFiles.isEmpty {
                FlowLayout(spacing: Theme.Space.x8) {
                    ForEach(session.tellFiles, id: \.self) { file in attachment(file) }
                }
            }
        }
        .padding(.vertical, Theme.Space.x14)
        .padding(.horizontal, Theme.Space.x16)
        .surface(Theme.Colors.freeAnswerFill, .composer, in: RoundedRectangle(cornerRadius: Theme.Radius.panel))
    }

    private func attachment(_ file: URL) -> some View {
        HStack(spacing: Theme.Space.x10) {
            Text(file.pathExtension.prefix(4).uppercased())
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(Theme.Colors.attachTileText)
                .frame(width: Theme.Size.panelTile, height: Theme.Size.panelTile)
                .background(Theme.Colors.attachTile, in: RoundedRectangle(cornerRadius: Theme.Radius.code))
            VStack(alignment: .leading, spacing: 0) {
                Text(file.lastPathComponent).textStyle(Theme.Text.calloutMedium).lineLimit(1)
                Text(Self.size(of: file)).textStyle(Theme.Text.caption).foregroundStyle(Theme.Colors.secondaryLabel)
            }
            Button { session.tellFiles.removeAll { $0 == file } } label: {
                DesignIcon(glyph: .close, size: 8, weight: 2.4)
                    .foregroundStyle(Theme.Colors.secondaryLabel)
                    .frame(width: 22, height: 22)
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Remove \(file.lastPathComponent)")
        }
        .padding(.leading, Theme.Space.x8)
        .padding(.trailing, Theme.Space.x6)
        .frame(height: Theme.Size.tellBar)
        .surface(Theme.Colors.background, .reviewFile, in: RoundedRectangle(cornerRadius: Theme.Radius.box))
    }

    private static func size(of file: URL) -> String {
        let bytes = (try? file.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
        return ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .file)
    }

    /// "Try something like": how to start, inserted into the box to finish in the user's words.
    private var examples: some View {
        let starters = [
            ("Add a rule", "Add a rule: "),
            ("Change how something works", "Change how … works: "),
            ("Leave something out", "Leave … out of the first version."),
        ]
        return VStack(alignment: .leading, spacing: Theme.Space.x2) {
            Text("Try something like").textStyle(Theme.Text.calloutBold).foregroundStyle(Theme.Colors.secondaryLabel)
                .padding(EdgeInsets(top: 0, leading: Theme.Space.x10, bottom: Theme.Space.x6, trailing: Theme.Space.x10))
            ForEach(starters, id: \.0) { label, text in
                Button {
                    session.tellDraft = text
                    isFocused = true
                } label: {
                    HStack(spacing: Theme.Space.x12) {
                        Image(systemName: "text.bubble").font(.system(size: 12)).foregroundStyle(Theme.Colors.bodyLabel)
                            .frame(width: Theme.Size.panelTile, height: Theme.Size.panelTile)
                            .background(Theme.Colors.chipFill, in: RoundedRectangle(cornerRadius: Theme.Radius.row))
                        VStack(alignment: .leading, spacing: 1) {
                            Text(label).textStyle(Theme.Text.bodyMedium)
                            Text(text).textStyle(Theme.Text.callout).foregroundStyle(Theme.Colors.secondaryLabel)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        DesignIcon(glyph: .chevronRight, size: Theme.Size.rowChevron).foregroundStyle(Theme.Colors.tertiary)
                    }
                    .padding(.vertical, Theme.Space.x8)
                    .padding(.horizontal, Theme.Space.x10)
                    .frame(minHeight: Theme.Size.intakeRow)
                    .contentShape(RoundedRectangle(cornerRadius: Theme.Radius.box))
                }
                .buttonStyle(.plain)
            }
        }
    }

    /// Build (V2-11): the task a request came from.
    private func chip(_ task: SpecTask) -> some View {
        HStack(spacing: Theme.Space.x6) {
            Text("Task \(task.number) · \(task.title.capitalizedFirst)").textStyle(Theme.Text.caption).lineLimit(1)
            Button { self.task = nil } label: {
                DesignIcon(glyph: .close, size: Theme.Size.removeIcon, weight: 2.4)
                    .frame(width: Theme.Size.removeButton, height: Theme.Size.removeButton)
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Remove task \(task.number)")
        }
        .foregroundStyle(Theme.Colors.likely)
        .padding(.leading, Theme.Space.x8)
        .padding(.trailing, Theme.Space.x4)
        .frame(height: Theme.Size.buttonMini)
        .background(Theme.Colors.changedFill, in: RoundedRectangle(cornerRadius: Theme.Radius.code))
    }

    private func send() {
        guard canSend else { return }
        let (request, files, about, only) = (self.request, session.tellFiles, task, scope)
        Task {
            // The words stay in the box until the change is in; Stop or a failed run leaves them there.
            guard await session.tell(request, files: files, task: about, only: only) else { return }
            if session.tellDraft.trimmingCharacters(in: .whitespacesAndNewlines) == request { session.tellDraft = "" }
            session.tellFiles = []
            if task == about { task = nil }
            if session.lastChange != nil, spec.unplacedChange == nil { reviewing = true }
        }
    }

    // MARK: Working (V2-25)

    private var working: some View {
        let rewriting = session.rewriting
        let found = session.tellFound
        let files = scope.map { [$0] } ?? spec.written
        let steps: [(String, String)] = rewriting.map { kind in [
            ("Read \(kind.fileName) and what depends on it", "\(spec.written.count) files"),
            ("Rewrite the whole file with your change", "As you chose"),
            ("Check it against the other files", "Mel’s own checks, no tokens"),
            ("Log your reason in DECISIONS.md", "In your words"),
        ] } ?? [
            ("Read the current files", "\(files.count) \(files.count == 1 ? "file" : "files"), from the last saved version"),
            ("Find where it goes", found.isEmpty ? "Looking…" : found.map(\.fileName).joined(separator: " · ")),
            ("Edit only those passages", "Small patches, not whole files"),
            ("Log your reason in DECISIONS.md", "In your words"),
        ]
        let current = rewriting != nil ? (session.liveText.isEmpty ? 0 : 1) : (found.isEmpty ? 0 : 1)
        return VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Space.x16) {
                    asked(session.telling ?? request)
                    VStack(spacing: 0) {
                        ForEach(Array(steps.enumerated()), id: \.offset) { i, step in
                            stepRow(step.0, detail: step.1, done: i < current, now: i == current)
                                .overlay(alignment: .top) { if i > 0 { Rectangle().fill(Theme.Colors.separatorTable).frame(height: 0.5) } }
                        }
                    }
                }
                .padding(EdgeInsets(top: 0, leading: Theme.Space.x20, bottom: Theme.Space.x16, trailing: Theme.Space.x20))
            }
            footer {
                Text("Nothing changes in your files until Mel finishes. Stop puts your words back in the box.")
                    .textStyle(Theme.Text.captionLoose)
                    .foregroundStyle(Theme.Colors.secondaryLabel)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Button("Stop") { Task { await session.stop() } }.buttonStyle(PanelButtonStyle())
            }
        }
    }

    private func stepRow(_ label: String, detail: String, done: Bool, now: Bool) -> some View {
        HStack(alignment: .top, spacing: Theme.Space.x12) {
            Group {
                if done { DoneMark(size: 18) }
                else if now { ProgressView().controlSize(.small) }
                else { Circle().strokeBorder(Theme.Colors.radioRing, lineWidth: 1.4).frame(width: 15, height: 15) }
            }
            .frame(width: 20, height: 20)
            VStack(alignment: .leading, spacing: Theme.Space.x2) {
                Text(label)
                    .textStyle(now ? Theme.Text.bodyBold : Theme.Text.body)
                    .foregroundStyle(done || now ? Theme.Colors.label : Theme.Colors.secondaryLabel)
                if done || now {
                    Text(detail).textStyle(Theme.Text.callout).foregroundStyle(Theme.Colors.secondaryLabel).fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 11)
        .padding(.horizontal, Theme.Space.x2)
    }

    /// What the user asked, quoted.
    private func asked(_ text: String) -> some View {
        HStack(alignment: .top, spacing: Theme.Space.x10) {
            Image(systemName: "quote.opening").font(.system(size: 11, weight: .bold)).foregroundStyle(Theme.Colors.tertiary).padding(.top, 3)
            Text(text).textStyle(Theme.Text.prose).foregroundStyle(Theme.Colors.bodyLabel).fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, Theme.Space.x12)
        .padding(.horizontal, Theme.Space.x14)
        .background(Theme.Colors.freeAnswerFill, in: RoundedRectangle(cornerRadius: Theme.Radius.card))
    }

    // MARK: Review (V2-26)

    static func reviewTitle(_ change: SpecSession.ChangeResult) -> String {
        guard !change.edits.isEmpty else { return change.line }
        let kept = change.edits.indices.filter { !change.reverted.contains($0) }
        let files = Set(kept.map { change.edits[$0].file }).count
        if kept.isEmpty { return "All changes undone" }
        return "\(kept.count) \(kept.count == 1 ? "change" : "changes") in \(files) \(files == 1 ? "file" : "files")"
    }

    /// The result line in Mel's column: what is still in after any Undo this.
    static func line(_ change: SpecSession.ChangeResult) -> String {
        guard !change.edits.isEmpty, !change.reverted.isEmpty else { return change.line }
        let kept = change.edits.indices.filter { !change.reverted.contains($0) }
        let files = Set(kept.map { change.edits[$0].file }).count
        return "Changed \(kept.count) \(kept.count == 1 ? "passage" : "passages") in \(files) \(files == 1 ? "file" : "files")"
    }

    static func note(_ change: SpecSession.ChangeResult, highlighted: Bool) -> String {
        let tokens = change.tokens > 0 ? " \(TokenStep.text(change.tokens)) tokens." : ""
        let rewrote = change.edits.isEmpty && change.line.hasPrefix("Rewrote")
        return (rewrote ? "You chose a full rewrite. Logged in DECISIONS.md." : (highlighted && !change.passages.isEmpty ? "Highlighted in the files. " : "") + "Your words are the reason in DECISIONS.md.") + tokens
    }

    @ViewBuilder
    private var review: some View {
        if let change = session.lastChange {
            let files = spec.size.files.filter { kind in change.edits.contains { $0.file == kind } }
            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: Theme.Space.x12) {
                        if !change.request.isEmpty { asked(change.request) }
                        ForEach(files, id: \.self) { kind in reviewFile(kind, change: change) }
                    }
                    .padding(EdgeInsets(top: 0, leading: Theme.Space.x20, bottom: Theme.Space.x16, trailing: Theme.Space.x20))
                }
                footer {
                    Text(Self.note(change, highlighted: false))
                        .textStyle(Theme.Text.captionLoose)
                        .foregroundStyle(Theme.Colors.secondaryLabel)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Button("Undo all") {
                        session.undoChange()
                        reviewing = false
                        close()
                    }
                    .buttonStyle(PanelButtonStyle())
                    .disabled(session.isRunning)
                    Button("Done", action: finish)
                        .buttonStyle(PanelButtonStyle(primary: true))
                        .keyboardShortcut(.defaultAction)
                }
            }
        }
    }

    private func reviewFile(_ kind: DocKind, change: SpecSession.ChangeResult) -> some View {
        let indices = change.edits.indices.filter { change.edits[$0].file == kind }
        let kept = indices.count { !change.reverted.contains($0) }
        return VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: Theme.Space.x8) {
                DesignIcon(glyph: .doc, size: 13).foregroundStyle(Theme.Colors.secondaryLabel)
                Text(kind.fileName).textStyle(Theme.Text.codeBold)
                Text(kept == 0 ? "Undone" : "\(kept) \(kept == 1 ? "change" : "changes")").textStyle(Theme.Text.caption).foregroundStyle(Theme.Colors.secondaryLabel)
                Spacer(minLength: 0)
                Button("Open") {
                    reviewing = false
                    close()
                    show(kind)
                }
                .buttonStyle(DesignLinkStyle())
                .padding(.horizontal, Theme.Space.x8)
            }
            .padding(.leading, Theme.Space.x12)
            .padding(.trailing, Theme.Space.x8)
            .frame(height: 38)
            .background(Theme.Colors.freeAnswerFill)
            .overlay(alignment: .bottom) { Rectangle().fill(Theme.Colors.separatorLight).frame(height: 0.5) }
            ForEach(Array(indices.enumerated()), id: \.element) { position, index in
                editRow(change.edits[index], section: change.sections.indices.contains(index) ? change.sections[index] : nil, undone: change.reverted.contains(index)) {
                    session.toggleEdit(index)
                }
                .overlay(alignment: .top) { if position > 0 { Rectangle().fill(Theme.Colors.separatorTable).frame(height: 0.5) } }
            }
        }
        .surface(Theme.Colors.background, .reviewFile, in: RoundedRectangle(cornerRadius: Theme.Radius.card))
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card))
        .accessibilityElement(children: .contain)
        .accessibilityLabel(kind.fileName)
    }

    private func editRow(_ edit: Change.Edit, section: String?, undone: Bool, toggle: @escaping () -> Void) -> some View {
        VStack(alignment: .leading, spacing: Theme.Space.x4) {
            HStack(spacing: Theme.Space.x8) {
                Text(section ?? "").textStyle(Theme.Text.captionBold).foregroundStyle(Theme.Colors.secondaryLabel).lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Button(undone ? "Redo" : "Undo this", action: toggle)
                    .buttonStyle(DesignLinkStyle())
                    .textStyle(Theme.Text.caption)
                    .padding(.horizontal, Theme.Space.x6)
                    .frame(height: 22)
                    .disabled(session.isRunning)
            }
            .padding(.bottom, Theme.Space.x2)
            if !edit.old.isEmpty { diffLine(edit.old, removed: true) }
            if !edit.new.isEmpty { diffLine(edit.new, removed: false) }
        }
        .padding(EdgeInsets(top: Theme.Space.x10, leading: Theme.Space.x12, bottom: Theme.Space.x12, trailing: Theme.Space.x12))
        .opacity(undone ? 0.45 : 1)
    }

    private func diffLine(_ text: String, removed: Bool) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: Theme.Space.x8) {
            Text(removed ? "−" : "+").textStyle(Theme.Text.bodyBold).foregroundStyle(removed ? Theme.Colors.removedSign : Theme.Colors.addedSign).frame(width: 10)
                .accessibilityLabel(removed ? "Removed" : "Added")
            Text(text.trimmingCharacters(in: .whitespacesAndNewlines))
                .textStyle(Theme.Text.bodyLoose)
                .foregroundStyle(removed ? Theme.Colors.removedLine : Theme.Colors.label)
                .strikethrough(removed, color: Theme.Colors.removedLine.opacity(0.4))
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)
        }
        .padding(.vertical, 5)
        .padding(.horizontal, Theme.Space.x8)
        .background(removed ? Theme.Colors.diffRemovedFill : Theme.Colors.diffAddedFill, in: RoundedRectangle(cornerRadius: Theme.Radius.code))
    }

    // MARK: Couldn't be placed (V2-27)

    @ViewBuilder
    private var unplaced: some View {
        if let unplaced = spec.unplacedChange {
            let file = unplaced.files.first
            let cost = file.flatMap { spec.tokens?[TokenStep(file: $0)] }
            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: Theme.Space.x12) {
                        HStack(alignment: .top, spacing: Theme.Space.x12) {
                            DesignIcon(glyph: .warning, size: 18).foregroundStyle(Theme.Colors.caution).padding(.top, 1)
                            VStack(alignment: .leading, spacing: Theme.Space.x4) {
                                Text("Nothing was changed").textStyle(Theme.Text.bodyBold).foregroundStyle(Theme.Colors.bannerTitle)
                                Text((unplaced.answers ? "Your answers don’t" : "“\(unplaced.request)” doesn’t") + " fit a single passage in \(file?.fileName ?? "the files").")
                                    .textStyle(Theme.Text.calloutLoose)
                                    .foregroundStyle(Theme.Colors.bodyLabel)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(Theme.Space.x14)
                        .surface(Theme.Colors.unplacedFill, .unplaced, in: RoundedRectangle(cornerRadius: Theme.Radius.card))
                        Text("How do you want to go on?").textStyle(Theme.Text.calloutBold).foregroundStyle(Theme.Colors.secondaryLabel)
                            .padding(EdgeInsets(top: Theme.Space.x4, leading: Theme.Space.x2, bottom: 0, trailing: Theme.Space.x2))
                        choice(icon: "arrow.clockwise", accent: true, title: "Rewrite \(file?.fileName ?? "the file")",
                               text: "Mel writes the whole file again with your change, then checks it against the other files. Logged in DECISIONS.md.",
                               badge: cost.map { "About \(TokenStep.text($0)) tokens" }) {
                            Task { await session.rewriteUnplaced() }
                        }
                        if !unplaced.answers {
                            choice(icon: "pencil", accent: false, title: "Say it differently",
                                   text: "Your words go back in the box. Name the part that should change.", badge: nil) {
                                Task { session.tellDraft = await session.cancelUnplaced() }
                            }
                        }
                    }
                    .padding(EdgeInsets(top: 0, leading: Theme.Space.x20, bottom: Theme.Space.x16, trailing: Theme.Space.x20))
                }
                footer {
                    Spacer(minLength: 0)
                    Button("Cancel", action: finish).buttonStyle(PanelButtonStyle())
                }
            }
        }
    }

    private func choice(icon: String, accent: Bool, title: String, text: String, badge: String?, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: Theme.Space.x12) {
                Image(systemName: icon).font(.system(size: 14, weight: .medium))
                    .foregroundStyle(accent ? Theme.Colors.link : Theme.Colors.bodyLabel)
                    .frame(width: 32, height: 32)
                    .background(accent ? Theme.Colors.changedFill : Theme.Colors.chipFill, in: RoundedRectangle(cornerRadius: 9))
                VStack(alignment: .leading, spacing: Theme.Space.x2) {
                    Text(title).textStyle(Theme.Text.bodyBold)
                    Text(text).textStyle(Theme.Text.calloutLoose).foregroundStyle(Theme.Colors.secondaryLabel).fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                if let badge {
                    Text(badge).textStyle(Theme.Text.caption).foregroundStyle(Theme.Colors.bodyLabel)
                        .padding(.horizontal, Theme.Space.x8).frame(height: 22)
                        .background(Theme.Colors.chipFill, in: Capsule())
                }
            }
            .padding(Theme.Space.x14)
            .surface(Theme.Colors.background, .panelButton, in: RoundedRectangle(cornerRadius: Theme.Radius.card))
            .contentShape(RoundedRectangle(cornerRadius: Theme.Radius.card))
        }
        .buttonStyle(.plain)
        .disabled(session.isRunning)
    }

    // MARK: Parts

    private func footer(@ViewBuilder _ content: () -> some View) -> some View {
        HStack(spacing: Theme.Space.x8) { content() }
            .padding(EdgeInsets(top: Theme.Space.x12, leading: Theme.Space.x20, bottom: Theme.Space.x12, trailing: Theme.Space.x16))
            .background(Theme.Colors.fillSubtle)
            .overlay(alignment: .top) { Rectangle().fill(Theme.Colors.separatorLight).frame(height: 0.5) }
    }
}

/// The panel's 32 pt buttons: white with a ring, or the accent Send / Done.
struct PanelButtonStyle: ButtonStyle {
    var primary = false
    var square = false
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .textStyle(primary ? Theme.Text.bodyBold : Theme.Text.body)
            .foregroundStyle(primary ? Theme.Colors.onAccent : Theme.Colors.label)
            .padding(.horizontal, square ? 0 : primary ? Theme.Space.x14 : Theme.Space.x12)
            .frame(width: square ? Theme.Size.panelButton : nil, height: Theme.Size.panelButton)
            .surface(primary ? (isEnabled ? Theme.Colors.accent : Theme.Colors.tertiary) : Theme.Colors.background, primary ? .init() : .panelButton, in: RoundedRectangle(cornerRadius: Theme.Radius.box))
            .opacity(configuration.isPressed ? 0.85 : 1)
            .contentShape(RoundedRectangle(cornerRadius: Theme.Radius.box))
    }
}
