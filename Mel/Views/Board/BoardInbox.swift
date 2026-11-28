import SwiftUI
import MelSpec

/// "Mel needs you" (V2-2, right column): one intake question at a time, then the decision cards
/// of each written file and of the check. Every one takes a tapped answer or anything typed.
struct BoardInbox: View {
    let session: SpecSession
    let openDecisions: () -> Void

    @State private var freeCard: String?
    @State private var freeText = ""
    /// A folded card the user tapped open (V2-29); answering moves on to the next open one.
    @State private var focused: String?

    private var spec: Spec { session.spec }
    private var isAsking: Bool { spec.stage == .discovery }

    private var title: String {
        if isAsking { return "Mel needs you" }
        let open = spec.openCards.count
        if open > 0 { return "Mel needs you · \(open)" }
        return spec.written == spec.size.files ? "All answered" : "All answered so far"
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Space.x10) {
                Text(title).textStyle(Theme.Text.boardTitle).accessibilityAddTraits(.isHeader)
                if isAsking { asking } else { planning }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Theme.Space.x16)
            // The next question, a card answered or reopened, a new file's cards.
            .animation(.board, value: spec.intakeCard?.id)
            .animation(.board, value: spec.cards.map { $0.id + ($0.answer == nil ? "?" : "") })
            .animation(.board, value: freeCard)
            .animation(.board, value: focused)
            .animation(.board, value: isAsking)
        }
        .foregroundStyle(Theme.Colors.label)
    }

    // MARK: Intake (V2-28)

    @ViewBuilder
    private var asking: some View {
        if let card = spec.intakeCard {
            let asked = spec.questions.filter { $0.round == .intake }
            let index = asked.firstIndex { $0.id == card.id } ?? 0
            let answered = asked.filter { $0.answer != nil }
            if !answered.isEmpty { answeredStack(answered) }
            VStack(alignment: .leading, spacing: Theme.Space.x14) {
                HStack(spacing: Theme.Space.x10) {
                    HStack(spacing: Theme.Space.x4) {
                        ForEach(asked.indices, id: \.self) { i in
                            Capsule().fill(i < index ? Theme.Colors.accent : i == index ? Theme.Colors.stepCurrent : Theme.Colors.selectionFill)
                                .frame(height: Theme.Size.questionBar)
                        }
                    }
                    .accessibilityHidden(true)
                    Text("Question \(index + 1) of \(asked.count)").textStyle(Theme.Text.caption).foregroundStyle(Theme.Colors.secondaryLabel).monospacedDigit()
                }
                VStack(alignment: .leading, spacing: Theme.Space.x4) {
                    Text(card.text).textStyle(Theme.Text.headline).fixedSize(horizontal: false, vertical: true)
                    if !card.why.isEmpty {
                        Text(card.why).textStyle(Theme.Text.calloutLoose).foregroundStyle(Theme.Colors.secondaryLabel).fixedSize(horizontal: false, vertical: true)
                    }
                }
                VStack(spacing: Theme.Space.x6) {
                    ForEach(Array(card.options.enumerated()), id: \.offset) { index, option in
                        let button = Button { Task { await session.answerIntake(.option(index, note: nil)) } } label: {
                            intakeRow(key: index + 1, label: option.label, likely: option.suggested)
                        }
                        .buttonStyle(.plain)
                        .keyboardShortcut(KeyEquivalent(Character("\(index + 1)")), modifiers: [])
                        // Return takes the likely answer.
                        if option.suggested { button.background { Button("") { Task { await session.answerIntake(.option(index, note: nil)) } }.keyboardShortcut(.defaultAction).hidden() } } else { button }
                    }
                    if freeCard == card.id {
                        freeAnswer(lines: Theme.Size.openAnswerLines, placeholder: "For example: at the desk for now, in the app from spring", save: "Use this answer") { text in
                            Task { await session.answerIntake(.text(text)) }
                        }
                    } else {
                        Button { openFree(card.id) } label: {
                            intakeRow(key: card.options.count + 1, label: "Something else…", likely: false, other: true)
                        }
                        .buttonStyle(.plain)
                        .keyboardShortcut(KeyEquivalent(Character("\(card.options.count + 1)")), modifiers: [])
                    }
                }
            }
            .padding(Theme.Space.x16)
            .surface(Theme.Colors.background, .questionCard, in: RoundedRectangle(cornerRadius: Theme.Radius.panel))
            .id(card.id)
            .transition(.asymmetric(insertion: .opacity.combined(with: .offset(x: 12)), removal: .opacity))
            VStack(alignment: .leading, spacing: Theme.Space.x2) {
                Button("Skip, write the plan now") { Task { await session.skipIntake() } }
                    .buttonStyle(DesignLinkStyle())
                    .padding(.vertical, Theme.Space.x2)
                Text("Mel takes the likely answer or guesses, and lists each guess so you can change it.")
                    .textStyle(Theme.Text.captionLoose)
                    .foregroundStyle(Theme.Colors.secondaryLabel)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, Theme.Space.x4)
        } else if let error = session.lastError {
            Text(error).textStyle(Theme.Text.calloutLoose).foregroundStyle(Theme.Colors.cautionText)
            HStack(spacing: Theme.Space.x8) {
                Button("Try Again") { Task { await session.start() } }.buttonStyle(BoardPillStyle())
                Button("Skip, write the plan now") { Task { await session.skipIntake() } }.buttonStyle(DesignLinkStyle())
            }
        } else {
            Text("Mel is reading your idea. Its questions appear here.")
                .textStyle(Theme.Text.calloutLoose)
                .foregroundStyle(Theme.Colors.secondaryLabel)
            Button("Skip, write the plan now") { Task { await session.skipIntake() } }
                .buttonStyle(DesignLinkStyle())
                .padding(.vertical, Theme.Space.x4)
        }
    }

    /// The intake questions already answered, above the one on screen, each with Change.
    private func answeredStack(_ answered: [Question]) -> some View {
        VStack(spacing: 0) {
            ForEach(Array(answered.enumerated()), id: \.element.id) { i, question in
                HStack(spacing: Theme.Space.x10) {
                    doneMark
                    VStack(alignment: .leading, spacing: 0) {
                        Text(question.title).textStyle(Theme.Text.caption).foregroundStyle(Theme.Colors.secondaryLabel).lineLimit(1)
                        Text(question.answerText ?? "").textStyle(Theme.Text.bodyMedium).lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    Button("Change") { session.reopenCard(question.id) }.buttonStyle(DesignLinkStyle())
                }
                .padding(.vertical, Theme.Space.x6)
                .padding(.horizontal, Theme.Space.x12)
                .frame(minHeight: Theme.Size.foldedRow)
                .overlay(alignment: .top) { if i > 0 { Rectangle().fill(Theme.Colors.separatorFaint).frame(height: 0.5) } }
            }
        }
        .surface(Theme.Colors.answeredStack, .answeredStack, in: RoundedRectangle(cornerRadius: Theme.Radius.card))
    }

    private var doneMark: some View {
        ZStack {
            Circle().fill(Theme.Colors.success)
            DesignIcon(glyph: .check, size: Theme.Size.smallCheck, weight: 2.2).foregroundStyle(Theme.Colors.onAccent)
        }
        .frame(width: 16, height: 16)
        .accessibilityHidden(true)
    }

    private func keycap(_ key: Int) -> some View {
        Text("\(key)")
            .textStyle(Theme.Text.captionBold)
            .foregroundStyle(Theme.Colors.secondaryLabel)
            .monospacedDigit()
            .frame(width: Theme.Size.keycap, height: Theme.Size.keycap)
            .surface(Theme.Colors.keycap, .keycap, in: RoundedRectangle(cornerRadius: Theme.Radius.code))
            .accessibilityHidden(true)
    }

    private func intakeRow(key: Int, label: String, likely: Bool, other: Bool = false) -> some View {
        HStack(spacing: Theme.Space.x10) {
            keycap(key)
            Text(label)
                .textStyle(Theme.Text.body)
                .foregroundStyle(other ? Theme.Colors.bodyLabel : Theme.Colors.label)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
            if likely {
                HStack(spacing: Theme.Space.x4) {
                    Text("Likely")
                    Text("↩").accessibilityHidden(true)
                }
                .textStyle(Theme.Text.captionMedium)
                .foregroundStyle(Theme.Colors.likely)
                .padding(.horizontal, 7)
                .frame(height: Theme.Size.questionPill)
                .background(Theme.Colors.likelyPill, in: Capsule())
            }
            if other {
                DesignIcon(glyph: .pencil, size: 13).foregroundStyle(Theme.Colors.secondaryLabel)
            }
        }
        .padding(.vertical, Theme.Space.x8)
        .padding(.horizontal, Theme.Space.x10)
        .frame(minHeight: Theme.Size.intakeRow)
        .surface(likely ? Theme.Colors.likelyFill : other ? .clear : Theme.Colors.background, likely ? .likelyRow : .answerRow, in: RoundedRectangle(cornerRadius: Theme.Radius.box))
        .contentShape(RoundedRectangle(cornerRadius: Theme.Radius.box))
    }

    // MARK: Cards (V2-29)

    /// The card that is open: the one the user tapped, else the first open one.
    private var activeID: String? {
        let open = spec.openCards
        if let focused, open.contains(where: { $0.id == focused }) { return focused }
        return open.first?.id
    }

    /// The written files' cards, each file one group, then the check's.
    private var groups: [(name: String, cards: [Card])] {
        var groups: [(name: String, cards: [Card])] = []
        for card in spec.cards {
            let name = card.file?.fileName ?? "Mel’s check"
            if groups.last?.name == name { groups[groups.count - 1].cards.append(card) } else { groups.append((name, [card])) }
        }
        return groups
    }

    @ViewBuilder
    private var planning: some View {
        let cards = spec.cards
        if !cards.isEmpty {
            let answered = cards.count { $0.answer != nil }
            HStack(spacing: Theme.Space.x10) {
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Theme.Colors.skeleton)
                        Capsule().fill(Theme.Colors.success).frame(width: geometry.size.width * CGFloat(answered) / CGFloat(cards.count))
                    }
                }
                .frame(height: Theme.Size.questionBar)
                .accessibilityHidden(true)
                Text("\(answered) of \(cards.count) answered").textStyle(Theme.Text.caption).foregroundStyle(Theme.Colors.secondaryLabel).monospacedDigit()
            }
            .padding(.horizontal, Theme.Space.x2)
            .padding(.top, Theme.Space.x2)
        }
        ForEach(groups, id: \.name) { group in
            let open = group.cards.count { $0.answer == nil }
            VStack(alignment: .leading, spacing: Theme.Space.x6) {
                HStack(spacing: Theme.Space.x6) {
                    DesignIcon(glyph: .doc, size: 12).foregroundStyle(Theme.Colors.secondaryLabel)
                    Text(group.name).textStyle(Theme.Text.codeCaptionBold).foregroundStyle(Theme.Colors.bodyLabel).frame(maxWidth: .infinity, alignment: .leading)
                    Text(open == 0 ? "All answered" : "\(open) open").textStyle(Theme.Text.caption).foregroundStyle(Theme.Colors.secondaryLabel)
                }
                .padding(.horizontal, Theme.Space.x4)
                .padding(.top, Theme.Space.x4)
                VStack(spacing: 0) {
                    ForEach(Array(group.cards.enumerated()), id: \.element.id) { i, card in
                        cardView(card)
                            .overlay(alignment: .top) { if i > 0 { Rectangle().fill(Theme.Colors.separatorTable).frame(height: 0.5) } }
                    }
                }
                .surface(Theme.Colors.background, .questionCard, in: RoundedRectangle(cornerRadius: Theme.Radius.panel))
                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.panel))
            }
            .accessibilityElement(children: .contain)
            .accessibilityLabel(group.name)
        }
        if spec.halted == nil, spec.written != spec.size.files {
            HStack(alignment: .firstTextBaseline, spacing: Theme.Space.x8) {
                if spec.gate == nil, session.isRunning { ProgressView().controlSize(.mini) }
                Text(waitText).textStyle(Theme.Text.calloutLoose).foregroundStyle(Theme.Colors.secondaryLabel)
            }
        }
        summary.padding(.top, Theme.Space.x4)
        // Start Building failed (the spec's commit, AGENTS.md).
        if spec.isReady, !session.isRunning, let error = session.lastError {
            Text(error).textStyle(Theme.Text.calloutLoose).foregroundStyle(Theme.Colors.cautionText)
        }
    }

    private var waitText: String {
        if let gate = spec.gate {
            return "\(gate.file.fileName) starts after \(BoardStatus.answers(gate.answers)) above. Writing files in order means a later answer never rewrites a finished file."
        }
        let next = spec.size.files.first { !spec.written.contains($0) }
        return "Mel is writing \(next?.fileName ?? "the next file"). Its questions appear here when it’s done."
    }

    private func topic(_ card: Card) -> String { card.topic.isEmpty ? card.location : card.topic }

    @ViewBuilder
    private func cardView(_ card: Card) -> some View {
        if let answer = card.answerText {
            HStack(spacing: Theme.Space.x10) {
                doneMark
                VStack(alignment: .leading, spacing: 0) {
                    Text(topic(card)).textStyle(Theme.Text.caption).foregroundStyle(Theme.Colors.secondaryLabel).lineLimit(1)
                    Text(answer).textStyle(Theme.Text.bodyMedium).lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Button("Change") { session.reopenCard(card.id) }.buttonStyle(DesignLinkStyle()).disabled(session.isRunning)
            }
            .padding(.vertical, Theme.Space.x8)
            .padding(.horizontal, Theme.Space.x14)
            .frame(minHeight: Theme.Size.foldedRow)
        } else if card.id == activeID {
            openCard(card)
        } else {
            Button { focused = card.id } label: {
                HStack(spacing: Theme.Space.x10) {
                    Circle().fill(card.disagrees ? Theme.Colors.failure : Theme.Colors.accent).frame(width: 8, height: 8)
                    VStack(alignment: .leading, spacing: 0) {
                        Text(topic(card)).textStyle(Theme.Text.caption).foregroundStyle(Theme.Colors.secondaryLabel).lineLimit(1)
                        Text(card.text).textStyle(Theme.Text.body).foregroundStyle(Theme.Colors.label).lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    DesignIcon(glyph: .chevronRight, size: Theme.Size.rowChevron).foregroundStyle(Theme.Colors.tertiary)
                }
                .padding(.vertical, Theme.Space.x8)
                .padding(.horizontal, Theme.Space.x14)
                .frame(minHeight: Theme.Size.foldedRow)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHint("Opens this question")
        }
    }

    /// The one open card: its question and answers; a contradiction's answers are its two sources.
    private func openCard(_ card: Card) -> some View {
        VStack(alignment: .leading, spacing: Theme.Space.x12) {
            if card.disagrees {
                HStack(spacing: 5) {
                    DesignIcon(glyph: .warning, size: 11).foregroundStyle(Theme.Colors.failure)
                    Text("These disagree").textStyle(Theme.Text.captionBold).foregroundStyle(Theme.Colors.disagreeText)
                }
                .padding(.leading, Theme.Space.x6)
                .padding(.trailing, Theme.Space.x8)
                .frame(height: Theme.Size.questionPill)
                .background(Theme.Colors.disagreePill, in: Capsule())
            } else if !topic(card).isEmpty {
                Text(topic(card)).textStyle(Theme.Text.captionBold).foregroundStyle(Theme.Colors.likely)
            }
            Text(card.text).textStyle(Theme.Text.cardQuestion).fixedSize(horizontal: false, vertical: true)
            if freeCard == card.id {
                freeAnswer(lines: Theme.Size.tellLines, placeholder: "", save: "Save answer") { text in
                    Task { await session.answerCard(card.id, .text(text)) }
                }
            } else {
                Group {
                    if card.disagrees {
                        LazyVGrid(columns: [GridItem(.flexible(), spacing: Theme.Space.x8), GridItem(.flexible())], spacing: Theme.Space.x8) {
                            ForEach(Array(card.options.enumerated()), id: \.offset) { index, option in
                                Button { Task { await session.answerCard(card.id, .option(index, note: nil)) } } label: {
                                    VStack(alignment: .leading, spacing: Theme.Space.x6) {
                                        Text(option.label).textStyle(Theme.Text.headline).fixedSize(horizontal: false, vertical: true)
                                        if !option.note.isEmpty {
                                            Text(option.note).textStyle(Theme.Text.caption).foregroundStyle(Theme.Colors.secondaryLabel).lineLimit(1)
                                        }
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.vertical, Theme.Space.x10)
                                    .padding(.horizontal, Theme.Space.x12)
                                    .surface(Theme.Colors.background, .cardAnswerRow, in: RoundedRectangle(cornerRadius: Theme.Radius.box))
                                    .contentShape(RoundedRectangle(cornerRadius: Theme.Radius.box))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    } else {
                        VStack(spacing: Theme.Space.x6) {
                            ForEach(Array(card.options.enumerated()), id: \.offset) { index, option in
                                Button { Task { await session.answerCard(card.id, .option(index, note: nil)) } } label: {
                                    HStack(spacing: Theme.Space.x10) {
                                        Circle().fill(Theme.Colors.background).frame(width: 16, height: 16)
                                            .overlay { Circle().strokeBorder(Theme.Colors.radioRing, lineWidth: 1.5) }
                                        Text(option.label).textStyle(Theme.Text.body).fixedSize(horizontal: false, vertical: true)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                    }
                                    .padding(.vertical, Theme.Space.x8)
                                    .padding(.horizontal, Theme.Space.x12)
                                    .frame(minHeight: Theme.Size.optionRow)
                                    .surface(Theme.Colors.background, .cardAnswerRow, in: RoundedRectangle(cornerRadius: Theme.Radius.box))
                                    .contentShape(RoundedRectangle(cornerRadius: Theme.Radius.box))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .disabled(session.isRunning)
                .opacity(session.isRunning ? 0.5 : 1)
                Button { openFree(card.id) } label: {
                    HStack(spacing: Theme.Space.x6) {
                        DesignIcon(glyph: .pencil, size: 11)
                        Text("Something else…")
                    }
                }
                .buttonStyle(DesignLinkStyle())
                .padding(.horizontal, Theme.Space.x2)
                .frame(height: 24)
                .disabled(session.isRunning)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Theme.Space.x14)
        .background(card.disagrees ? Theme.Colors.disagreeFill : .clear)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(topic(card))
    }

    private func openFree(_ id: String) {
        freeText = ""
        freeCard = id
    }

    /// "Something else…": the typed answer is used exactly like a tapped one.
    private func freeAnswer(lines: Int, placeholder: String, save: String, use: @escaping (String) -> Void) -> some View {
        let text = freeText.trimmingCharacters(in: .whitespacesAndNewlines)
        return VStack(alignment: .leading, spacing: Theme.Space.x8) {
            Text("Your answer, in your own words").textStyle(Theme.Text.captionBold).foregroundStyle(Theme.Colors.bodyLabel)
            TextField(placeholder, text: $freeText, axis: .vertical)
                .lineLimit(lines...8)
                .textFieldStyle(.plain)
                .textStyle(Theme.Text.bodyLoose)
                .accessibilityLabel("Your answer, in your own words")
            HStack(spacing: Theme.Space.x6) {
                Spacer(minLength: 0)
                Button("Cancel") { freeCard = nil }
                    .buttonStyle(.plain)
                    .textStyle(Theme.Text.callout)
                    .foregroundStyle(Theme.Colors.bodyLabel)
                    .padding(.horizontal, Theme.Space.x10)
                    .frame(height: Theme.Size.button)
                Button(save) {
                    freeCard = nil
                    use(text)
                }
                .buttonStyle(BoardPillStyle(kind: .accent))
                .disabled(text.isEmpty)
            }
        }
        .padding(.vertical, Theme.Space.x10)
        .padding(.horizontal, Theme.Space.x12)
        .surface(Theme.Colors.freeAnswerFill, .freeAnswer, in: RoundedRectangle(cornerRadius: Theme.Radius.box))
    }

    // MARK: Summary

    private var summary: some View {
        let answers = spec.questions.count { $0.answer != nil && $0.answer != .agentDecides }
        let guesses = spec.questions.count { $0.answer == .agentDecides } + spec.written.reduce(0) { $0 + session.summary($1).assumptions }
        let decisions = session.decisions.count
        return VStack(alignment: .leading, spacing: Theme.Space.x2) {
            Text("\(answers) \(answers == 1 ? "answer" : "answers") you gave").textStyle(Theme.Text.callout).padding(.vertical, Theme.Space.x4)
            Text("\(guesses) small \(guesses == 1 ? "thing" : "things") Mel guessed").textStyle(Theme.Text.callout).padding(.vertical, Theme.Space.x4)
            Button(action: openDecisions) {
                HStack(spacing: Theme.Space.x6) {
                    Text("\(decisions) \(decisions == 1 ? "decision" : "decisions") with reasons")
                        .textStyle(Theme.Text.callout)
                        .foregroundStyle(Theme.Colors.label)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text("Open").textStyle(Theme.Text.callout).foregroundStyle(Theme.Colors.link)
                }
                .padding(.vertical, Theme.Space.x4)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, Theme.Space.x10)
        .padding(.horizontal, Theme.Space.x12)
        .surface(.clear, .outlineReplaced, in: RoundedRectangle(cornerRadius: Theme.Radius.box))
    }
}

/// An answer on a decision card: a full-width row whose text wraps. "Something else…" is the quiet one.
struct CardOptionStyle: ButtonStyle {
    var quiet = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .textStyle(Theme.Text.callout)
            .foregroundStyle(quiet ? Theme.Colors.bodyLabel : Theme.Colors.label)
            .multilineTextAlignment(.leading)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, Theme.Space.x6)
            .padding(.horizontal, Theme.Space.x12)
            .frame(minHeight: Theme.Size.button)
            .surface(quiet ? .clear : Theme.Colors.background, quiet ? .pillOutline : .answerPill, in: RoundedRectangle(cornerRadius: Theme.Radius.row))
            .opacity(configuration.isPressed ? 0.7 : 1)
            .contentShape(RoundedRectangle(cornerRadius: Theme.Radius.row))
    }
}
