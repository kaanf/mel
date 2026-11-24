import SwiftUI
import MelSpec

/// B2 Intake (design/v2 Native-2-Discovery): the round-1 questions one at a time, answered list above,
/// coverage in the inspector.
struct DiscoveryView: View {
    let session: SpecSession
    @Binding var showInspector: Bool
    @State private var editingIdea = false
    @State private var width: CGFloat = .infinity
    /// The question on screen when Discovery was opened. It doesn't take keyboard focus, so arrow keys
    /// keep moving through the sidebar; questions that arrive later do (digits and ↩ work right away).
    @State private var openedOn: String?

    init(session: SpecSession, showInspector: Binding<Bool>) {
        self.session = session
        _showInspector = showInspector
        _openedOn = State(initialValue: session.currentQuestion?.id)
    }

    private var spec: Spec { session.spec }
    private var intakeCount: Int { spec.questions.count { $0.round == .intake } }
    private var number: Int { session.answeredQuestions.count + 1 }
    /// "2 of 5" while a question is open.
    private var progress: String? { session.currentQuestion == nil || intakeCount == 0 ? nil : "\(number) of \(intakeCount)" }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Space.x20) {
                StageStepper(steps: ["Idea", progress.map { "Intake \($0)" } ?? "Intake", "Draft", "Review"], current: spec.stage == .discovery ? 1 : 2)
                    .padding(.horizontal, Theme.Space.x12)
                section("Your Idea") {
                    HStack(alignment: .top, spacing: Theme.Space.x12) {
                        Text(spec.idea)
                            .textStyle(Theme.Text.body)
                            .foregroundStyle(Theme.Colors.label)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Button("Edit…") { editingIdea = true }
                            .buttonStyle(DesignLinkStyle(text: Theme.Text.body))
                            .disabled(session.isRunning)
                    }
                    .padding(.vertical, Theme.Space.x10)
                    .padding(.horizontal, Theme.Space.x12)
                    .background(Theme.Colors.fill, in: RoundedRectangle(cornerRadius: Theme.Radius.box))
                }
                if !session.answeredQuestions.isEmpty {
                    section("Answered") { AnsweredList(session: session) }
                }
                current
            }
            .frame(maxWidth: Theme.Size.intakeWidth)
            .padding(EdgeInsets(top: Theme.Space.x12, leading: Theme.Space.x24, bottom: Theme.Space.x32, trailing: Theme.Space.x24))
            .frame(maxWidth: .infinity)
        }
        .background(Theme.Colors.background)
        .navigationTitle("Discovery")
        .navigationSubtitle(spec.name)
        .toolbar {
            // Two items, not one: NSToolbar doesn't widen an item whose content grows.
            if compact {
                ToolbarItem(placement: .principal) { status }.sharedBackgroundVisibility(.hidden)
            } else {
                ToolbarItem(placement: .principal) { status }.sharedBackgroundVisibility(.hidden)
            }
            if spec.stage == .discovery {
                ToolbarItem {
                    Button { Task { await session.draftNow() } } label: {
                        HStack(spacing: Theme.Space.x6) {
                            DesignIcon(glyph: .draftNow, size: Theme.Size.alertIcon)
                            Text("Draft Now").textStyle(Theme.Text.body)
                        }
                        .foregroundStyle(Theme.Colors.label)
                        .padding(.horizontal, Theme.Space.x6)
                    }
                    .help("Skip the remaining questions. The agent fills gaps and marks each one as an assumption.")
                    .disabled(session.isRunning)
                }
            }
            ToolbarItem {
                Button { showInspector.toggle() } label: {
                    DesignIcon(glyph: .inspector, size: Theme.Size.settingsIcon).foregroundStyle(Theme.Colors.label)
                }
                .accessibilityLabel(showInspector ? "Hide inspector" : "Show inspector")
                .help("Show or hide the inspector")
            }
        }
        .inspector(isPresented: $showInspector) {
            DiscoveryInspector(spec: spec)
                .inspectorColumnWidth(min: Theme.Size.inspectorWidth, ideal: Theme.Size.inspectorWidth, max: Theme.Size.inspectorWidth)
        }
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = $0 }
        .focusedSceneValue(\.inspectorShown, $showInspector)
        .sheet(isPresented: $editingIdea) {
            IdeaEditor(idea: spec.idea) { session.updateIdea($0) }
        }
    }

    private func section(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: Theme.Space.x6) {
            Text(title)
                .textStyle(Theme.Text.bodyBold)
                .foregroundStyle(Theme.Colors.label)
                .padding(.horizontal, Theme.Space.x12)
                .accessibilityAddTraits(.isHeader)
            content()
        }
    }

    @ViewBuilder
    private var current: some View {
        if let question = session.currentQuestion {
            QuestionCard(session: session, question: question, number: number, total: intakeCount, takesFocus: question.id != openedOn) { await session.answer($0) }
                .id(question.id)
        } else if let error = session.lastError {
            VStack(alignment: .leading, spacing: Theme.Space.x8) {
                Text("Claude Code could not continue")
                    .textStyle(Theme.Text.bodyBold)
                    .foregroundStyle(Theme.Colors.label)
                Text(error)
                    .textStyle(Theme.Text.caption)
                    .foregroundStyle(Theme.Colors.secondaryLabel)
                    .textSelection(.enabled)
                Button("Try Again") { Task { await session.retry() } }
                    .buttonStyle(DesignButtonStyle(role: .secondary, height: Theme.Size.button, leading: Theme.Space.x16, trailing: Theme.Space.x16, text: Theme.Text.body))
            }
            .padding(Theme.Space.x12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.Colors.fill, in: RoundedRectangle(cornerRadius: Theme.Radius.box))
        } else if session.isRunning {
            HStack(spacing: Theme.Space.x8) {
                StatusDot(style: .running)
                Text("Claude Code is preparing the questions…")
                    .textStyle(Theme.Text.callout)
                    .foregroundStyle(Theme.Colors.secondaryLabel)
            }
            .padding(.horizontal, Theme.Space.x12)
        } else if spec.stage != .discovery {
            Text("Intake is complete. The spec files are in the sidebar.")
                .textStyle(Theme.Text.callout)
                .foregroundStyle(Theme.Colors.secondaryLabel)
                .padding(.horizontal, Theme.Space.x12)
        }
    }

    private var compact: Bool { width < ToolbarStatus.fullTextWidth }

    @ViewBuilder
    private var status: some View {
        if session.currentQuestion != nil {
            StatusPill(indicator: .needsYou, text: compact ? "Needs you" : "Needs you · Claude Code is waiting for an answer", count: progress ?? "", maxWidth: compact ? Theme.Size.statusPillCompact : Theme.Size.statusPillIntake)
        } else if session.lastError != nil {
            StatusPill(indicator: .idle, text: "Stopped", count: "", maxWidth: compact ? Theme.Size.statusPillCompact : Theme.Size.statusPillIntake)
        } else if session.isRunning {
            StatusPill(indicator: .running, text: compact ? "Running" : "Running · Claude Code is preparing the questions", count: "", maxWidth: compact ? Theme.Size.statusPillCompact : Theme.Size.statusPillIntake)
        }
    }
}

/// "Your Idea › Edit…".
private struct IdeaEditor: View {
    @State var idea: String
    let save: (String) -> Void
    @Environment(\.dismiss) private var dismiss

    private var trimmed: String { idea.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Edit Your Idea").font(.headline)
            TextEditor(text: $idea)
                .font(.body)
                .frame(height: 140)
            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Save") {
                    save(trimmed)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(trimmed.isEmpty)
            }
        }
        .padding(20)
        .frame(width: 480)
    }
}

/// Answered questions, one 36 pt row each; click to change the answer.
private struct AnsweredList: View {
    let session: SpecSession

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(session.answeredQuestions.enumerated()), id: \.element.id) { index, question in
                if index > 0 { rowSeparator }
                if question.options.isEmpty {
                    TextAnswerRow(question: question, text: answerText(question)) { change(question, to: $0) }
                        .disabled(session.isRunning)
                } else {
                    Menu {
                        ForEach(question.options.indices, id: \.self) { index in
                            Button(question.options[index].label) { change(question, to: .option(index, note: nil)) }
                        }
                        Divider()
                        Button("Decide Later") { change(question, to: .agentDecides) }
                    } label: {
                        AnsweredRow(title: question.title, answer: answerText(question))
                    }
                    .menuStyle(.button)
                    .buttonStyle(.plain)
                    .menuIndicator(.hidden)
                    .help("Change this answer")
                    .disabled(session.isRunning)
                }
            }
        }
        .background(Theme.Colors.fill, in: RoundedRectangle(cornerRadius: Theme.Radius.box))
    }

    private func change(_ question: Question, to answer: Answer) {
        Task { await session.changeAnswer(questionID: question.id, to: answer) }
    }

    private func answerText(_ question: Question) -> String {
        switch question.answer {
        case .option(let index, let note):
            let label = question.options.indices.contains(index) ? question.options[index].label : "Option \(index + 1)"
            return note.map { "\(label) · \($0)" } ?? label
        case .text(let text): return text
        case .agentDecides: return "Later · the agent decides"
        case nil: return ""
        }
    }
}

private var rowSeparator: some View {
    Rectangle().fill(Theme.Colors.separator).frame(height: Theme.Size.hairline).padding(.leading, Theme.Space.x12)
}

private struct AnsweredRow: View {
    let title: String
    let answer: String

    var body: some View {
        HStack(spacing: Theme.Space.x8) {
            Text(title)
                .textStyle(Theme.Text.body)
                .foregroundStyle(Theme.Colors.label)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(answer)
                .textStyle(Theme.Text.body)
                .foregroundStyle(Theme.Colors.secondaryLabel)
                .lineLimit(1)
            DesignIcon(glyph: .chevronRight, size: Theme.Size.rowChevron)
                .foregroundStyle(Theme.Colors.secondaryLabel)
        }
        .padding(.horizontal, Theme.Space.x12)
        .frame(height: Theme.Size.answeredRow)
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
    }
}

/// Answered open question: click to edit the text; saving it empty leaves it to the agent.
private struct TextAnswerRow: View {
    let question: Question
    let text: String
    let change: (Answer) -> Void
    @State private var editing = false
    @State private var draft = ""

    var body: some View {
        Button {
            if case .text(let text) = question.answer { draft = text } else { draft = "" }
            editing = true
        } label: {
            AnsweredRow(title: question.title, answer: text)
        }
        .buttonStyle(.plain)
        .help("Change this answer")
        .popover(isPresented: $editing, arrowEdge: .bottom) {
            VStack(alignment: .leading, spacing: 12) {
                Text(question.title).font(.headline)
                TextField("Your answer", text: $draft, axis: .vertical)
                    .lineLimit(3...8)
                    .onSubmit(save)
                HStack {
                    Text("Leave empty to let the agent decide.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Cancel") { editing = false }
                        .keyboardShortcut(.cancelAction)
                    Button("Save", action: save)
                        .keyboardShortcut(.defaultAction)
                }
            }
            .padding(16)
            .frame(width: 400)
        }
    }

    private func save() {
        let trimmed = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        let answer: Answer = trimmed.isEmpty ? .agentDecides : .text(trimmed)
        editing = false
        if answer != question.answer { change(answer) }
    }
}

/// One question with its options or answer field, footer hint, Decide Later and Continue (B2; B4's round 2).
struct QuestionCard: View {
    let session: SpecSession
    let question: Question
    let number: Int
    let total: Int
    let takesFocus: Bool
    /// Where the answer goes: `session.answer` in the intake, `answerFollowUp` for round 2.
    let onAnswer: (Answer) async -> Void
    @State private var choice: Int?
    @State private var note = ""
    @State private var text = ""
    @FocusState private var cardFocused: Bool
    @FocusState private var noteFocused: Bool

    init(session: SpecSession, question: Question, number: Int, total: Int, takesFocus: Bool, onAnswer: @escaping (Answer) async -> Void) {
        self.session = session
        self.question = question
        self.number = number
        self.total = total
        self.takesFocus = takesFocus
        self.onAnswer = onAnswer
        _choice = State(initialValue: question.options.firstIndex(where: \.suggested))
    }

    private var isOpen: Bool { question.options.isEmpty }
    private var trimmedText: String { text.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.x20) {
            VStack(alignment: .leading, spacing: Theme.Space.x6) {
                HStack(alignment: .firstTextBaseline, spacing: Theme.Space.x8) {
                    Text(total > 0 ? "Question \(number) of \(total)" : "Question \(number)")
                        .textStyle(Theme.Text.bodyBold)
                        .foregroundStyle(Theme.Colors.label)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .accessibilityAddTraits(.isHeader)
                    Text("Shapes \(question.shapes.fileName)")
                        .textStyle(Theme.Text.caption)
                        .foregroundStyle(Theme.Colors.secondaryLabel)
                }
                .padding(.horizontal, Theme.Space.x12)
                card
            }
            footer
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Question \(number)")
        .focusable()
        .focusEffectDisabled()
        .focused($cardFocused)
        .onAppear {
            guard takesFocus else { return }
            if isOpen { noteFocused = true } else { cardFocused = true }
        }
        // Digits pick an option unless a text field is taking text; ↩ is Continue (default action).
        .onKeyPress(characters: .decimalDigits) { press in
            guard !isOpen, !noteFocused, let digit = Int(press.characters), (1...question.options.count).contains(digit) else { return .ignored }
            choice = digit - 1
            return .handled
        }
    }

    private var card: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: Theme.Space.x2) {
                Text(question.title)
                    .textStyle(Theme.Text.bodyBold)
                    .foregroundStyle(Theme.Colors.label)
                Text(question.why)
                    .textStyle(Theme.Text.caption)
                    .foregroundStyle(Theme.Colors.secondaryLabel)
            }
            .padding(EdgeInsets(top: Theme.Space.x12, leading: Theme.Space.x12, bottom: Theme.Space.x10, trailing: Theme.Space.x12))
            if !isOpen {
                ForEach(question.options.indices, id: \.self) { index in
                    let option = question.options[index]
                    rowSeparator
                    RadioRow(label: option.label, note: option.note, suggested: option.suggested, keyHint: "\(index + 1)", isSelected: choice == index) {
                        choice = index
                    }
                }
            }
            rowSeparator
            VStack(alignment: .leading, spacing: Theme.Space.x6) {
                Text(isOpen ? "Your answer" : "Note for the agent (optional)")
                    .textStyle(Theme.Text.caption)
                    .foregroundStyle(Theme.Colors.secondaryLabel)
                if isOpen {
                    TextField("Your answer", text: $text, prompt: Text("Your answer").foregroundStyle(Theme.Colors.tertiary), axis: .vertical)
                        .lineLimit(Theme.Size.openAnswerLines, reservesSpace: true)
                        .onSubmit { if !trimmedText.isEmpty && !session.isRunning { submit() } }
                        .modifier(NoteField())
                        .focused($noteFocused)
                        .accessibilityLabel("Your answer")
                } else {
                    TextField("Note for the agent", text: $note, prompt: Text("Note for the agent").foregroundStyle(Theme.Colors.tertiary))
                        .modifier(NoteField())
                        .frame(height: Theme.Size.button)
                        .focused($noteFocused)
                        .accessibilityLabel("Note for the agent, optional")
                }
            }
            .padding(EdgeInsets(top: Theme.Space.x10, leading: Theme.Space.x12, bottom: Theme.Space.x12, trailing: Theme.Space.x12))
        }
        .background(Theme.Colors.fill, in: RoundedRectangle(cornerRadius: Theme.Radius.box))
    }

    private var footer: some View {
        HStack(spacing: Theme.Space.x8) {
            Text(isOpen ? "Decide Later lets the agent decide. Answers can be changed later." : "Press 1 to \(question.options.count) to choose. Answers can be changed later.")
                .textStyle(Theme.Text.caption)
                .foregroundStyle(Theme.Colors.secondaryLabel)
                .padding(.leading, Theme.Space.x12)
                .frame(maxWidth: .infinity, alignment: .leading)
            Button("Decide Later") { Task { await onAnswer(.agentDecides) } }
                .buttonStyle(DesignButtonStyle(role: .secondary, height: Theme.Size.button, leading: Theme.Space.x16, trailing: Theme.Space.x16, text: Theme.Text.body))
                .disabled(session.isRunning)
            Button("Continue", action: submit)
                .buttonStyle(DesignButtonStyle(height: Theme.Size.button, leading: Theme.Space.x16, trailing: Theme.Space.x16, keyHint: "↩"))
                .keyboardShortcut(.defaultAction)
                .disabled((isOpen ? trimmedText.isEmpty : choice == nil) || session.isRunning)
        }
    }

    private func submit() {
        if isOpen {
            Task { await onAnswer(.text(trimmedText)) }
            return
        }
        guard let choice else { return }
        Task { await onAnswer(.option(choice, note: note.isEmpty ? nil : note)) }
    }
}

/// The note field (B2): white, 7 pt corners, hairline ring with an inner shadow.
private struct NoteField: ViewModifier {
    func body(content: Content) -> some View {
        content
            .textFieldStyle(.plain)
            .textStyle(Theme.Text.body)
            .foregroundStyle(Theme.Colors.label)
            .labelsHidden()
            .padding(.horizontal, Theme.Space.x8)
            .padding(.vertical, Theme.Space.x5)
            .frame(maxWidth: .infinity, alignment: .leading)
            .surface(Theme.Colors.background, .field, in: RoundedRectangle(cornerRadius: Theme.Radius.field))
    }
}

/// B2 inspector: Understanding (coverage) and Agent.
private struct DiscoveryInspector: View {
    let spec: Spec

    private var covered: Int { spec.coverage.count { $0.state == .covered } }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Space.x20) {
                VStack(alignment: .leading, spacing: Theme.Space.x8) {
                    heading("Understanding")
                    HStack(spacing: Theme.Space.x8) {
                        GeometryReader { proxy in
                            Capsule().fill(Theme.Colors.selectionFill)
                                .overlay(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: Theme.Radius.progress)
                                        .fill(Theme.Colors.secondaryLabel)
                                        .frame(width: spec.coverage.isEmpty ? 0 : proxy.size.width * CGFloat(covered) / CGFloat(spec.coverage.count))
                                }
                                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.progress))
                        }
                        .frame(height: Theme.Size.understandingBar)
                        Text("\(covered) of \(spec.coverage.count)")
                            .textStyle(Theme.Text.caption)
                            .foregroundStyle(Theme.Colors.secondaryLabel)
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("Understanding")
                    .accessibilityValue("\(covered) of \(spec.coverage.count)")
                    VStack(spacing: 0) {
                        ForEach(spec.coverage, id: \.label) { item in coverageRow(item) }
                    }
                    .padding(.vertical, Theme.Space.x4)
                    .background(Theme.Colors.fill, in: RoundedRectangle(cornerRadius: Theme.Radius.box))
                    Text("Intake asks only what shapes the draft. Gaps Mel finds in the draft come back as a short second round.")
                        .textStyle(Theme.Text.caption)
                        .foregroundStyle(Theme.Colors.secondaryLabel)
                }
                VStack(alignment: .leading, spacing: Theme.Space.x8) {
                    heading("Agent")
                    VStack(spacing: 0) {
                        infoRow("Claude Code", value: sizeWord, mono: false)
                        rowSeparator
                        infoRow("Folder", value: "specs/", mono: true)
                    }
                    .background(Theme.Colors.fill, in: RoundedRectangle(cornerRadius: Theme.Radius.box))
                }
            }
            .padding(EdgeInsets(top: 0, leading: Theme.Space.x16, bottom: Theme.Space.x16, trailing: Theme.Space.x16))
        }
        .background(Theme.Colors.background)
    }

    private var sizeWord: String {
        switch spec.size {
        case .quickFix: "Quick fix"
        case .feature: "Feature spec"
        case .product: "Product spec"
        }
    }

    private func heading(_ text: String) -> some View {
        Text(text)
            .textStyle(Theme.Text.captionBold)
            .foregroundStyle(Theme.Colors.secondaryLabel)
            .accessibilityAddTraits(.isHeader)
    }

    private func coverageRow(_ item: CoverageItem) -> some View {
        HStack(spacing: Theme.Space.x8) {
            Group {
                switch item.state {
                case .covered: DesignIcon(glyph: .check, size: Theme.Size.smallCheck, weight: 2.2).foregroundStyle(Theme.Colors.success)
                case .asking: DesignIcon(glyph: .arrowRight, size: Theme.Size.smallCheck).foregroundStyle(Theme.Colors.label)
                case .notYet, .later: StatusDot(style: .ring(Theme.Colors.secondaryLabel))
                }
            }
            .frame(width: Theme.Size.smallCheck, height: Theme.Size.smallCheck)
            Text(item.label)
                .textStyle(Theme.Text.body)
                .foregroundStyle(Theme.Colors.label)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(Self.word(item.state))
                .textStyle(Theme.Text.caption)
                .foregroundStyle(Theme.Colors.secondaryLabel)
        }
        .padding(.horizontal, Theme.Space.x12)
        .frame(height: Theme.Size.coverageRow)
        .accessibilityElement(children: .combine)
    }

    static func word(_ state: CoverageState) -> String {
        switch state {
        case .covered: "Covered"
        case .asking: "Asking"
        case .notYet: "Not yet"
        case .later: "Round 2"
        }
    }

    private func infoRow(_ label: String, value: String, mono: Bool) -> some View {
        HStack(spacing: Theme.Space.x8) {
            Text(label)
                .textStyle(Theme.Text.body)
                .foregroundStyle(Theme.Colors.label)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(value)
                .textStyle(mono ? Theme.Text.codeCaption : Theme.Text.caption)
                .foregroundStyle(Theme.Colors.secondaryLabel)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .padding(.horizontal, Theme.Space.x12)
        .frame(height: Theme.Size.inspectorRow)
        .accessibilityElement(children: .combine)
    }
}

#Preview("Question") {
    @Previewable @State var showInspector = true
    NavigationStack {
        DiscoveryView(session: PreviewData.session(PreviewData.intake), showInspector: $showInspector)
    }
    .frame(width: 1048, height: 800)
}

#Preview("Open Question") {
    @Previewable @State var showInspector = true
    NavigationStack {
        DiscoveryView(session: PreviewData.session(PreviewData.discoveryOpen), showInspector: $showInspector)
    }
    .frame(width: 1048, height: 800)
}

#Preview("Inspector") {
    DiscoveryInspector(spec: PreviewData.discovery)
        .frame(width: Theme.Size.inspectorWidth, height: 600)
}

#Preview("Edit Idea") {
    IdeaEditor(idea: PreviewData.idea) { _ in }
}

#Preview("Thinking") {
    @Previewable @State var showInspector = false
    NavigationStack {
        DiscoveryView(session: PreviewData.session(PreviewData.discoveryThinking, isRunning: true), showInspector: $showInspector)
    }
    .frame(width: 760, height: 600)
}

#Preview("Error") {
    @Previewable @State var showInspector = false
    NavigationStack {
        DiscoveryView(
            session: PreviewData.session(PreviewData.discoveryThinking, lastError: "Claude Code's answer could not be read as questions."),
            showInspector: $showInspector
        )
    }
    .frame(width: 760, height: 600)
}

#Preview("Complete") {
    @Previewable @State var showInspector = false
    NavigationStack {
        DiscoveryView(session: PreviewData.session(PreviewData.review), showInspector: $showInspector)
    }
    .frame(width: 760, height: 600)
}
