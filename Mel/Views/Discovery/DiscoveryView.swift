import SwiftUI
import MelSpec

/// Questions one at a time, answered list above, coverage in the inspector.
struct DiscoveryView: View {
    let session: SpecSession
    @Binding var showInspector: Bool
    @State private var editingIdea = false

    private var spec: Spec { session.spec }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                StageStepper(current: 1)
                GroupBox {
                    Text(spec.idea)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } label: {
                    HStack {
                        Text("Your Idea")
                        Spacer()
                        Button("Edit…") { editingIdea = true }
                            .buttonStyle(.link)
                            .disabled(session.isRunning)
                    }
                }
                if !session.answeredQuestions.isEmpty {
                    AnsweredList(session: session)
                }
                current
            }
            .frame(maxWidth: 620)
            .padding(24)
            .frame(maxWidth: .infinity)
        }
        .navigationTitle("Discovery")
        .navigationSubtitle(spec.name)
        .toolbar {
            ToolbarItem(placement: .status) { status.padding(.horizontal, 10) }   // the glass capsule adds no inset of its own
            if spec.stage == .discovery {
                ToolbarItem {
                    Button("Draft Now") { Task { await session.draftNow() } }
                        .help("Skip the remaining questions. The agent decides the rest and marks each decision as an assumption.")
                        .disabled(session.isRunning)
                }
            }
            ToolbarItem {
                Button("Inspector", systemImage: "sidebar.trailing") { showInspector.toggle() }
                    .help("Show or hide the inspector")
            }
        }
        .inspector(isPresented: $showInspector) {
            DiscoveryInspector(spec: spec)
                .inspectorColumnWidth(min: 220, ideal: 260)
        }
        .focusedSceneValue(\.inspectorShown, $showInspector)
        .sheet(isPresented: $editingIdea) {
            IdeaEditor(idea: spec.idea) { session.updateIdea($0) }
        }
    }

    @ViewBuilder
    private var current: some View {
        if let question = session.currentQuestion {
            QuestionCard(session: session, question: question, number: session.answeredQuestions.count + 1)
                .id(question.id)
        } else if let error = session.lastError {
            GroupBox {
                VStack(alignment: .leading, spacing: 8) {
                    StatusBadge(status: .stopped, title: "Claude Code could not continue")
                    Text(error)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                    Button("Try Again") { Task { await session.retry() } }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        } else if session.isRunning {
            HStack(spacing: 8) {
                ProgressView().controlSize(.small)
                Text("Claude Code is thinking about the next question…")
                    .foregroundStyle(.secondary)
            }
        } else if spec.stage != .discovery {
            Text("Discovery is complete. The spec files are in the sidebar.")
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var status: some View {
        if session.currentQuestion != nil {
            StatusBadge(status: .needsYou, title: "Needs you · Claude Code is waiting for an answer")
        } else if session.lastError != nil {
            StatusBadge(status: .stopped)
        } else if session.isRunning {
            StatusBadge(status: .checking, title: "Running · Claude Code is thinking")
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

private struct AnsweredList: View {
    let session: SpecSession

    var body: some View {
        GroupBox("Answered") {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(session.answeredQuestions) { question in
                    if question.options.isEmpty {
                        TextAnswerRow(question: question, text: answerText(question)) { change(question, to: $0) }
                            .disabled(session.isRunning)
                    } else {
                        Menu {
                            ForEach(question.options.indices, id: \.self) { index in
                                Button(question.options[index].label) { change(question, to: .option(index, note: nil)) }
                            }
                            Divider()
                            Button("You Decide") { change(question, to: .agentDecides) }
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(question.title)
                                    .foregroundStyle(.secondary)
                                Text(answerText(question))
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(.rect)
                        }
                        .menuStyle(.button)
                        .buttonStyle(.plain)
                        .menuIndicator(.hidden)
                        .help("Change this answer")
                        .disabled(session.isRunning)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
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
        case .agentDecides: return question.options.isEmpty ? "Skipped · the agent decides" : "You decide"
        case nil: return ""
        }
    }
}

/// Answered open question: click to edit the text; saving it empty skips the question.
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
            VStack(alignment: .leading, spacing: 2) {
                Text(question.title)
                    .foregroundStyle(.secondary)
                Text(text)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(.rect)
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

private struct QuestionCard: View {
    let session: SpecSession
    let question: Question
    let number: Int
    @State private var choice: Int?
    @State private var note = ""
    @State private var text = ""
    @FocusState private var cardFocused: Bool
    @FocusState private var noteFocused: Bool

    /// `question.options.count` stands for "You decide".
    init(session: SpecSession, question: Question, number: Int) {
        self.session = session
        self.question = question
        self.number = number
        _choice = State(initialValue: question.options.firstIndex(where: \.suggested))
    }

    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Question \(number)")
                    Text("·")
                    Text("Shapes \(question.shapes.fileName)")
                }
                .font(.callout)
                .foregroundStyle(.secondary)
                Text(question.title)
                    .font(.title3.bold())
                Text(question.why)
                    .foregroundStyle(.secondary)
                if question.options.isEmpty {
                    openAnswer
                } else {
                    optionAnswer
                }
            }
            .padding(4)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Question \(number)")
        .focusable()
        .focusEffectDisabled()
        .focused($cardFocused)
        .onAppear {
            if question.options.isEmpty { noteFocused = true } else { cardFocused = true }
        }
        // Digits pick an option unless a text field is taking text; ↩ is Continue (default action).
        .onKeyPress(characters: .decimalDigits) { press in
            guard !question.options.isEmpty, !noteFocused, let digit = Int(press.characters), (1...question.options.count + 1).contains(digit) else { return .ignored }
            choice = digit - 1
            return .handled
        }
    }

    private var trimmedText: String { text.trimmingCharacters(in: .whitespacesAndNewlines) }

    /// Open question: multi-line answer (↩ continues, ⌥↩ adds a line), or Skip.
    @ViewBuilder
    private var openAnswer: some View {
        TextField("Your answer", text: $text, axis: .vertical)
            .lineLimit(3...8)
            .focused($noteFocused)
            .onSubmit { if !trimmedText.isEmpty && !session.isRunning { submit() } }
        HStack {
            Text("Skip lets the agent decide. Answers can be changed later.")
                .font(.callout)
                .foregroundStyle(.secondary)
            Spacer()
            Button("Skip") { Task { await session.answer(.agentDecides) } }
                .disabled(session.isRunning)
            Button("Continue", action: submit)
                .keyboardShortcut(.defaultAction)
                .disabled(trimmedText.isEmpty || session.isRunning)
        }
    }

    @ViewBuilder
    private var optionAnswer: some View {
        VStack(spacing: 2) {
            ForEach(question.options.indices, id: \.self) { index in
                let option = question.options[index]
                RadioRow(label: option.label, note: option.note, suggested: option.suggested, keyHint: "\(index + 1)", isSelected: choice == index) {
                    choice = index
                }
            }
            RadioRow(
                label: "You decide",
                note: "The agent picks the best option and marks it as an assumption",
                keyHint: "\(question.options.count + 1)",
                isSelected: choice == question.options.count
            ) {
                choice = question.options.count
            }
        }
        TextField("Note for the agent (optional)", text: $note)
            .focused($noteFocused)
        HStack {
            Text("Press 1 to \(question.options.count + 1) to choose. Answers can be changed later.")
                .font(.callout)
                .foregroundStyle(.secondary)
            Spacer()
            Button("Continue", action: submit)
                .keyboardShortcut(.defaultAction)
                .disabled(choice == nil || session.isRunning)
        }
    }

    private func submit() {
        if question.options.isEmpty {
            Task { await session.answer(.text(trimmedText)) }
            return
        }
        guard let choice else { return }
        let answer: Answer = choice == question.options.count
            ? .agentDecides
            : .option(choice, note: note.isEmpty ? nil : note)
        Task { await session.answer(answer) }
    }
}

private struct DiscoveryInspector: View {
    let spec: Spec

    /// Phases in file order, only those with coverage items.
    private var phases: [DocKind] { DocKind.allCases.filter { kind in spec.coverage.contains { $0.phase == kind } } }

    var body: some View {
        Form {
            ForEach(phases, id: \.self) { phase in
                let items = spec.coverage.filter { $0.phase == phase }
                Section {
                    ForEach(items, id: \.label) { item in
                    Label {
                        Text(item.label)
                    } icon: {
                        switch item.state {
                        case .covered: Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                        case .asking: Image(systemName: "circle.inset.filled").foregroundStyle(.purple)
                        case .notYet: Image(systemName: "circle").foregroundStyle(.secondary)
                        }
                    }
                    .accessibilityValue(item.state == .covered ? "Covered" : item.state == .asking ? "Asking" : "Not yet")
                    }
                } header: {
                    HStack {
                        Text(phase.title)
                        Spacer()
                        Text("\(items.count { $0.state == .covered }) of \(items.count)")
                            .monospacedDigit()
                    }
                } footer: {
                    if phase == phases.last {
                        Text("Questions continue until every item is covered.")
                    }
                }
            }
            Section {
                LabeledContent("Agent", value: "Claude Code · Spec mode")
                LabeledContent("Folder", value: "\(spec.folder.lastPathComponent)/")
            }
        }
        .formStyle(.grouped)
    }
}

#Preview("Question") {
    @Previewable @State var showInspector = true
    NavigationStack {
        DiscoveryView(session: PreviewData.session(PreviewData.discovery), showInspector: $showInspector)
    }
    .frame(width: 1000, height: 800)
}

#Preview("Open Question") {
    @Previewable @State var showInspector = true
    NavigationStack {
        DiscoveryView(session: PreviewData.session(PreviewData.discoveryOpen), showInspector: $showInspector)
    }
    .frame(width: 1000, height: 900)
}

#Preview("Inspector") {
    DiscoveryInspector(spec: PreviewData.discovery)
        .frame(width: 260, height: 600)
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
