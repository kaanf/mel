import SwiftUI
import MelSpec

/// B4 Review (design/v2 Native-3-Review): one drafted file as an article or editable Markdown,
/// "Before you approve", Approve. EXPERIENCE.md is B5 (Native-3b-Experience): flows, states table, Approve only.
/// The review inspector and agent suggestions are hidden in v0.3 (V2 §2).
struct ReviewView: View {
    let session: SpecSession
    let kind: DocKind
    @State private var mode = Mode.preview
    @State private var text: String
    @State private var blocks: [Block] = []
    @State private var summary = DocSummary()
    @State private var editing: (index: Int, text: String)?
    @State private var editText = ""
    @State private var answering: OpenQuestion?
    @State private var openAnswer = ""
    @State private var showsRoundTwo = false
    @State private var showReady = false
    @State private var width: CGFloat = .infinity

    enum Mode { case preview, edit }

    init(session: SpecSession, kind: DocKind, mode: Mode = .preview) {
        self.session = session
        self.kind = kind
        _mode = State(initialValue: mode)
        _text = State(initialValue: session.documents[kind] ?? "")
    }

    private var spec: Spec { session.spec }
    private var files: [DocKind] { spec.size.files }
    private var isApproved: Bool { spec.docs[kind] == .approved }
    /// Open items don't block: they stay marked in the file for the next agent.
    private var canApprove: Bool { spec.docs[kind] == .review }
    private var next: DocKind? { spec.size.file(after: kind) }
    private var assumptions: [Int] { blocks.compactMap { if case .assumption(let i, _) = $0 { i } else { nil } } }
    private var openQuestions: [Int] { blocks.compactMap { if case .openQuestion(let i, _) = $0 { i } else { nil } } }
    private var roundTwo: [Question] { spec.questions.filter { $0.round == .draft && $0.shapes == kind && $0.answer == nil } }
    private var compact: Bool { width < ToolbarStatus.fullTextWidth }
    private var isExperience: Bool { kind == .experience }
    /// B5: screens in the states table with a missing (`!`) state, and the states missing.
    private var missingStates: (screens: Int, states: Set<String>) {
        var screens = 0
        var states = Set<String>()
        for case .table(let header, let rows) in blocks where header.count == 3 && header[1] == "States" {
            for row in rows where row.count > 1 {
                let missing = row[1].split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { $0.hasPrefix("!") }
                if !missing.isEmpty { screens += 1 }
                states.formUnion(missing.map { String($0.dropFirst()) })
            }
        }
        return (screens, states)
    }

    var body: some View {
        content
            .background(Theme.Colors.background)
            .navigationTitle(kind.fileName)
            .navigationSubtitle(isExperience ? "Flows, screens and states" : "Saved · your edits are never overwritten")
            .toolbar { toolbar }
            .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = $0 }
            .focusedSceneValue(\.approve, approveAction)
            .task(id: text) {
                let parsed = await parseDocument(text, kind: kind)
                blocks = parsed.0
                summary = parsed.1
                if text != session.documents[kind] { session.save(text, for: kind) }   // session debounces the write
            }
            .onChange(of: session.documents[kind]) { _, new in
                if let new, new != text { text = new }
            }
            .onChange(of: spec.stage) { _, stage in
                if stage == .done { showReady = true }
            }
            .alert("Change Assumption", isPresented: Binding(get: { editing != nil }, set: { if !$0 { editing = nil } })) {
                TextField("Assumption", text: $editText)
                Button("Cancel", role: .cancel) {}
                Button("Save") {
                    if let editing { session.changeAssumption(index: editing.index, to: editText, in: kind) }
                }
            } message: {
                Text("Say what should be true instead. The file is updated and the assumption counts as confirmed.")
            }
            .alert("Answer Open Question", isPresented: Binding(get: { answering != nil }, set: { if !$0 { answering = nil } })) {
                TextField("Answer", text: $openAnswer)
                Button("Cancel", role: .cancel) { openAnswer = "" }
                Button("Answer") {
                    let answer = openAnswer.trimmingCharacters(in: .whitespacesAndNewlines)
                    openAnswer = ""
                    if let answering, !answer.isEmpty { Task { await session.answerOpenQuestion(answering, answer) } }
                }
            } message: {
                Text(answering.map { "\($0.text) The agent revises \(kind.fileName) with your answer." } ?? "")
            }
            .alert("\(kind.fileName) changed in another app", isPresented: Binding(get: { session.conflict == kind }, set: { _ in })) {
                Button("Keep Mine") { session.resolveConflict(keepMine: true) }
                Button("Use File") { session.resolveConflict(keepMine: false) }
            } message: {
                Text("You also have unsaved edits here. Keep Mine replaces the file with your edits. Use File loads the file and drops your edits.")
            }
            .sheet(isPresented: $showsRoundTwo) { roundTwoSheet }
            .sheet(isPresented: $showReady) {
                SpecReadySheet(session: session)
            }
    }

    // MARK: Content

    private var content: some View {
        ScrollViewReader { proxy in
            ScrollView {
                Group {
                    switch mode {
                    case .preview: article(proxy)
                    case .edit: editor
                    }
                }
                .frame(maxWidth: isExperience ? Theme.Size.experienceMaxWidth : Theme.Size.articleMaxWidth, alignment: .leading)
                .padding(EdgeInsets(top: Theme.Space.x20, leading: Theme.Space.x32, bottom: Theme.Space.x40, trailing: Theme.Space.x32))
                .frame(maxWidth: .infinity)
            }
        }
    }

    private func article(_ proxy: ScrollViewProxy) -> some View {
        // The file's H1 is the article title; the summary and the checklist come right after it.
        let hasTitle = if case .heading(1, _)? = blocks.first { true } else { false }
        return VStack(alignment: .leading, spacing: Theme.Space.x14) {
            if hasTitle { MarkdownBlocksView(blocks: Array(blocks.prefix(1)), isExperience: isExperience) }
            Text("\(summary.line(for: kind)) Written from \(source), project context and your answers.")
                .textStyle(Theme.Text.body)
                .foregroundStyle(Theme.Colors.secondaryLabel)
            if !checklistRows.isEmpty {
                checklist(proxy)
            }
            MarkdownBlocksView(
                blocks: Array(blocks.dropFirst(hasTitle ? 1 : 0)),
                onConfirm: { session.confirmAssumption(index: $0, in: kind) },
                onChange: { index, text in
                    editText = text
                    editing = (index, text)
                },
                onAnswer: { index, text in answering = OpenQuestion(kind: kind, index: index, text: text) },
                isExperience: isExperience
            )
        }
    }

    private var editor: some View {
        TextEditor(text: $text)
            .font(Theme.Text.codeBlock.font)
            .lineHeight(.exact(points: Theme.Text.codeBlock.lineHeight!))
            .foregroundStyle(Theme.Colors.label)
            .scrollContentBackground(.hidden)
            .scrollDisabled(true)
            .accessibilityLabel("\(kind.fileName) source, editable")
    }

    private var source: String {
        files.firstIndex(of: kind).flatMap { $0 > 0 ? files[$0 - 1].fileName : nil } ?? "your idea"
    }

    /// "Before you approve": round-2 gaps, assumptions, open questions. Suggestions are hidden in v0.3.
    private func checklist(_ proxy: ScrollViewProxy) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Before you approve")
                .textStyle(Theme.Text.bodyBold)
                .padding(EdgeInsets(top: Theme.Space.x10, leading: Theme.Space.x12, bottom: Theme.Space.x6, trailing: Theme.Space.x12))
            let rows = checklistRows
            ForEach(rows.indices, id: \.self) { index in
                if index > 0 {
                    Rectangle().fill(Theme.Colors.separator).frame(height: Theme.Size.hairline).padding(.leading, Theme.Size.checklistSeparatorInset)
                }
                checklistRow(rows[index], proxy: proxy)
            }
            if isExperience {
                Color.clear.frame(height: Theme.Space.x4)
            } else {
                Text("You can approve anyway. Open items stay marked in the file so the next agent sees them.")
                    .textStyle(Theme.Text.caption)
                    .foregroundStyle(Theme.Colors.secondaryLabel)
                    .padding(EdgeInsets(top: Theme.Space.x4, leading: Theme.Space.x12, bottom: Theme.Space.x10, trailing: Theme.Space.x12))
            }
        }
        .foregroundStyle(Theme.Colors.label)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.Colors.fill, in: RoundedRectangle(cornerRadius: Theme.Radius.box))
    }

    private enum ChecklistRow { case missingStates(Int, Set<String>), roundTwo(Int), assumptions(Int), openQuestions(Int) }

    private var checklistRows: [ChecklistRow] {
        var rows: [ChecklistRow] = []
        let missing = missingStates
        if missing.screens > 0 { rows.append(.missingStates(missing.screens, missing.states)) }
        if !roundTwo.isEmpty { rows.append(.roundTwo(roundTwo.count)) }
        if !assumptions.isEmpty { rows.append(.assumptions(assumptions.count)) }
        if !openQuestions.isEmpty { rows.append(.openQuestions(openQuestions.count)) }
        return rows
    }

    @ViewBuilder
    private func checklistRow(_ row: ChecklistRow, proxy: ScrollViewProxy) -> some View {
        switch row {
        case .missingStates(let screens, let states):
            // "2 screens have no error state" when one state is missing everywhere.
            let text = states.count == 1
                ? "\(screens == 1 ? "1 screen has" : "\(screens) screens have") no \(states.first!.lowercased()) state"
                : "\(screens == 1 ? "1 screen has" : "\(screens) screens have") missing states"
            Button { withAnimation { proxy.scrollTo("states", anchor: .top) } } label: {
                HStack(spacing: Theme.Space.x8) {
                    StatusDot(style: .filled(Theme.Colors.caution)).frame(width: Theme.Size.checklistIcon)
                    Text(text).textStyle(Theme.Text.body).frame(maxWidth: .infinity, alignment: .leading)
                    DesignIcon(glyph: .chevronRight, size: Theme.Size.rowChevron).foregroundStyle(Theme.Colors.secondaryLabel)
                }
                .padding(.horizontal, Theme.Space.x12)
                .frame(height: Theme.Size.checklistRow)
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
        case .roundTwo(let n):
            Button { showsRoundTwo = true } label: {
                HStack(spacing: Theme.Space.x8) {
                    Circle().fill(Theme.Colors.accent).frame(width: Theme.Size.statusDot, height: Theme.Size.statusDot)
                        .frame(width: Theme.Size.checklistIcon)
                    Text("Round 2: \(n == 1 ? "1 gap" : "\(n) gaps") found in this draft")
                        .textStyle(Theme.Text.body)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text(n == 1 ? "Answer 1 Question" : "Answer \(n) Questions")
                        .textStyle(Theme.Text.callout)
                        .foregroundStyle(Theme.Colors.link)
                }
                .padding(.horizontal, Theme.Space.x12)
                .frame(minHeight: Theme.Size.checklistRow)
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
        case .assumptions(let n):
            jumpRow(glyph: .star, text: n == 1 ? "1 assumption to confirm" : "\(n) assumptions to confirm") {
                if let first = assumptions.first { withAnimation { proxy.scrollTo("assumption-\(first)", anchor: .top) } }
            }
        case .openQuestions(let n):
            jumpRow(glyph: .question, text: n == 1 ? "1 open question" : "\(n) open questions") {
                if let first = openQuestions.first { withAnimation { proxy.scrollTo("open-question-\(first)", anchor: .top) } }
            }
        }
    }

    private func jumpRow(glyph: DesignIcon.Glyph, text: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: Theme.Space.x8) {
                DesignIcon(glyph: glyph, size: Theme.Size.checklistIcon, weight: 1.5)
                Text(text)
                    .textStyle(Theme.Text.body)
                    .frame(maxWidth: .infinity, alignment: .leading)
                DesignIcon(glyph: .chevronRight, size: Theme.Size.rowChevron).foregroundStyle(Theme.Colors.secondaryLabel)
            }
            .padding(.horizontal, Theme.Space.x12)
            .frame(height: Theme.Size.checklistRow)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }

    /// Round 2 from "Answer n Questions": the first open gap; answering starts a revise run of the file.
    @ViewBuilder
    private var roundTwoSheet: some View {
        VStack(alignment: .leading, spacing: Theme.Space.x16) {
            if let question = roundTwo.first {
                QuestionCard(session: session, question: question, number: 1, total: roundTwo.count, takesFocus: true) { answer in
                    showsRoundTwo = false
                    await session.answerFollowUp(questionID: question.id, answer)
                }
                .id(question.id)
            }
            HStack {
                Spacer()
                Button("Cancel") { showsRoundTwo = false }.keyboardShortcut(.cancelAction)
            }
        }
        .padding(Theme.Space.x20)
        .frame(width: Theme.Size.intakeWidth + Theme.Space.x40)
        .background(Theme.Colors.background)
    }

    // MARK: Toolbar

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        if compact {
            ToolbarItem(placement: .principal) { status }.sharedBackgroundVisibility(.hidden)
        } else {
            ToolbarItem(placement: .principal) { status }.sharedBackgroundVisibility(.hidden)
        }
        if !isExperience {
            ToolbarItem {
                HStack(spacing: Theme.Space.x2) {
                    modeButton(.preview, glyph: .docLines, label: "Preview")
                    modeButton(.edit, glyph: .code, label: "Edit Markdown")
                }
            }
            ToolbarItem {
                HStack(spacing: Theme.Space.x2) {
                    Button { session.showInFinder() } label: { toolbarIcon(.folder) }
                        .accessibilityLabel("Show in Finder")
                        .help("Show in Finder")
                    ShareLink(item: spec.folder.appending(path: kind.fileName)) { toolbarIcon(.share) }
                        .accessibilityLabel("Share")
                }
            }
        }
        if spec.stage == .done {
            ToolbarItem {
                Button("Start Building…") { showReady = true }
                    .buttonStyle(DesignButtonStyle(height: Theme.Size.buttonToolbar, leading: Theme.Space.x16, trailing: Theme.Space.x16))
            }
            .sharedBackgroundVisibility(.hidden)
        } else if !isApproved {
            ToolbarItem {
                Button("Approve", action: approve)
                    .buttonStyle(DesignButtonStyle(height: Theme.Size.buttonToolbar, leading: Theme.Space.x16, trailing: Theme.Space.x16, keyHint: "⌘↩"))
                    .disabled(!canApprove)
                    .help("Approve (⌘↩)")
            }
            .sharedBackgroundVisibility(.hidden)
        }
    }

    @ViewBuilder
    private var status: some View {
        let count = files.firstIndex(of: kind).map { "\($0 + 1) of \(files.count)" } ?? ""
        let maxWidth = compact ? Theme.Size.statusPillCompact : isExperience ? Theme.Size.statusPillExperience : Theme.Size.statusPillReview
        if let next, !isApproved {
            StatusPill(indicator: .idle, text: compact ? "Idle" : "Idle · \(next.fileName) starts when you approve", count: count, maxWidth: maxWidth)
        } else {
            StatusPill(indicator: .idle, text: isApproved ? "Approved" : "Idle", count: count, maxWidth: maxWidth)
        }
    }

    private func modeButton(_ value: Mode, glyph: DesignIcon.Glyph, label: String) -> some View {
        Button { mode = value } label: {
            toolbarIcon(glyph)
                .background(mode == value ? Theme.Colors.selectionFill : .clear, in: Capsule())
        }
        .accessibilityLabel(label)
        .accessibilityAddTraits(mode == value ? .isSelected : [])
        .help(label)
    }

    private func toolbarIcon(_ glyph: DesignIcon.Glyph) -> some View {
        DesignIcon(glyph: glyph, size: Theme.Size.settingsIcon)
            .foregroundStyle(Theme.Colors.label)
            .frame(width: Theme.Size.toolbarSegmentWidth, height: Theme.Size.button)
            .contentShape(Capsule())
    }

    private var approveAction: (() -> Void)? {
        guard canApprove else { return nil }
        return { approve() }
    }

    private func approve() {
        Task { await session.approve(kind) }
    }
}

#Preview("Review") {
    NavigationStack {
        ReviewView(session: PreviewData.reviewSession, kind: .requirements)
    }
    .environment(PreviewData.appState([PreviewData.reviewRoundTwo]))
    .frame(width: 1048, height: 800)
}

#Preview("Changed in another app") {
    NavigationStack {
        ReviewView(session: PreviewData.session(PreviewData.review, conflict: .requirements), kind: .requirements, mode: .edit)
    }
    .environment(PreviewData.appState([PreviewData.review]))
    .frame(width: 1000, height: 720)
}

#Preview("Edit Markdown") {
    NavigationStack {
        ReviewView(session: PreviewData.reviewSession, kind: .requirements, mode: .edit)
    }
    .environment(PreviewData.appState([PreviewData.reviewRoundTwo]))
    .frame(width: 1048, height: 800)
}

#Preview("Done") {
    NavigationStack {
        ReviewView(session: PreviewData.session(PreviewData.done), kind: .tasks)
    }
    .environment(PreviewData.appState([PreviewData.done]))
    .frame(width: 1000, height: 720)
}
