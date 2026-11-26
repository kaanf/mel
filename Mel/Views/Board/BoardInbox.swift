import SwiftUI
import MelSpec

/// "Mel needs you" (V2-2, right column): one intake question at a time, then the decision cards
/// of each written file and of the check. Every one takes a tapped answer or anything typed.
struct BoardInbox: View {
    let session: SpecSession
    let openDecisions: () -> Void

    @State private var freeCard: String?
    @State private var freeText = ""

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
        }
        .foregroundStyle(Theme.Colors.label)
        .background(Theme.Colors.fillSubtle)
    }

    // MARK: Intake

    @ViewBuilder
    private var asking: some View {
        if let card = spec.intakeCard {
            let asked = spec.questions.filter { $0.round == .intake }
            let number = (asked.firstIndex { $0.id == card.id } ?? 0) + 1
            VStack(alignment: .leading, spacing: Theme.Space.x10) {
                Text("Question \(number) of \(asked.count)").textStyle(Theme.Text.captionBold).foregroundStyle(Theme.Colors.secondaryLabel)
                Text(card.text).textStyle(Theme.Text.sectionTitle)
                if !card.why.isEmpty {
                    Text(card.why).textStyle(Theme.Text.calloutLoose).foregroundStyle(Theme.Colors.secondaryLabel)
                }
                VStack(spacing: Theme.Space.x6) {
                    ForEach(Array(card.options.enumerated()), id: \.offset) { index, option in
                        Button { Task { await session.answerIntake(.option(index, note: nil)) } } label: {
                            optionRow(key: index + 1, label: option.label, likely: option.suggested)
                        }
                        .buttonStyle(.plain)
                        .keyboardShortcut(KeyEquivalent(Character("\(index + 1)")), modifiers: [])
                    }
                }
                if freeCard == card.id {
                    freeAnswer(lines: Theme.Size.openAnswerLines, placeholder: "For example: at the desk for now, in the app from spring", save: "Use this answer") { text in
                        Task { await session.answerIntake(.text(text)) }
                    }
                } else {
                    Button { openFree(card.id) } label: {
                        optionRow(key: card.options.count + 1, label: "Something else…", likely: false, quiet: true)
                    }
                    .buttonStyle(.plain)
                    .keyboardShortcut(KeyEquivalent(Character("\(card.options.count + 1)")), modifiers: [])
                }
            }
            .padding(Theme.Space.x14)
            .surface(Theme.Colors.background, .inboxCard, in: RoundedRectangle(cornerRadius: Theme.Radius.card))
            .id(card.id)
            Button("Skip, write the plan now") { Task { await session.skipIntake() } }
                .buttonStyle(DesignLinkStyle())
                .padding(.vertical, Theme.Space.x4)
            Text("Skipped questions become guesses you can check later.")
                .textStyle(Theme.Text.captionLoose)
                .foregroundStyle(Theme.Colors.secondaryLabel)
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

    private func optionRow(key: Int, label: String, likely: Bool, quiet: Bool = false) -> some View {
        HStack(spacing: Theme.Space.x10) {
            Text("\(key)")
                .textStyle(Theme.Text.caption)
                .foregroundStyle(Theme.Colors.secondaryLabel)
                .frame(width: Theme.Size.optionKey, height: Theme.Size.optionKey)
                .background(Theme.Colors.chipFill, in: RoundedRectangle(cornerRadius: Theme.Radius.progressLarge))
            Text(label)
                .textStyle(Theme.Text.body)
                .foregroundStyle(quiet ? Theme.Colors.bodyLabel : Theme.Colors.label)
                .frame(maxWidth: .infinity, alignment: .leading)
            if likely {
                Text("Likely").textStyle(Theme.Text.caption).foregroundStyle(Theme.Colors.likely)
            }
        }
        .padding(.vertical, Theme.Space.x8)
        .padding(.horizontal, Theme.Space.x10)
        .frame(minHeight: Theme.Size.optionRow)
        .surface(quiet ? .clear : Theme.Colors.background, .outlineList, in: RoundedRectangle(cornerRadius: Theme.Radius.box))
        .contentShape(RoundedRectangle(cornerRadius: Theme.Radius.box))
    }

    // MARK: Cards

    @ViewBuilder
    private var planning: some View {
        ForEach(spec.cards) { card in
            cardView(card)
        }
        if spec.halted == nil, spec.written != spec.size.files {
            Text(waitText).textStyle(Theme.Text.calloutLoose).foregroundStyle(Theme.Colors.secondaryLabel)
        }
        summary.padding(.top, Theme.Space.x4)
    }

    private var waitText: String {
        if let gate = spec.gate {
            return "\(gate.file.fileName) starts after \(BoardStatus.answers(gate.answers)) above. Writing files in order means a later answer never rewrites a finished file."
        }
        let next = spec.size.files.first { !spec.written.contains($0) }
        return "Mel is writing \(next?.fileName ?? "the next file"). Its questions appear here when it’s done."
    }

    private func cardView(_ card: Card) -> some View {
        let done = card.answer != nil
        return VStack(alignment: .leading, spacing: Theme.Space.x8) {
            if card.disagrees, !done {
                HStack(spacing: Theme.Space.x6) {
                    Circle().fill(Theme.Colors.failure).frame(width: Theme.Size.statusDot, height: Theme.Size.statusDot)
                    Text("These disagree").textStyle(Theme.Text.captionBold).foregroundStyle(Theme.Colors.disagreeText)
                }
            }
            if !card.location.isEmpty {
                Text(card.location).textStyle(Theme.Text.caption).foregroundStyle(Theme.Colors.secondaryLabel)
            }
            Text(card.text).textStyle(Theme.Text.body)
            if let answer = card.answerText {
                HStack(spacing: Theme.Space.x6) {
                    DesignIcon(glyph: .check, size: Theme.Size.smallCheck, weight: 2.2).foregroundStyle(Theme.Colors.success)
                    Text(answer).textStyle(Theme.Text.calloutMedium).frame(maxWidth: .infinity, alignment: .leading)
                    Button("Change") { session.reopenCard(card.id) }.buttonStyle(DesignLinkStyle()).disabled(session.isRunning)
                }
            } else if freeCard == card.id {
                freeAnswer(lines: Theme.Size.tellLines, placeholder: "", save: "Save answer") { text in
                    Task { await session.answerCard(card.id, .text(text)) }
                }
            } else {
                FlowLayout(spacing: Theme.Space.x6) {
                    ForEach(Array(card.options.enumerated()), id: \.offset) { index, option in
                        Button(option.label) { Task { await session.answerCard(card.id, .option(index, note: nil)) } }
                            .buttonStyle(BoardPillStyle(elevation: .answerPill))
                    }
                    Button { openFree(card.id) } label: {
                        Text("Something else…")
                            .textStyle(Theme.Text.callout)
                            .foregroundStyle(Theme.Colors.bodyLabel)
                            .padding(.horizontal, Theme.Space.x12)
                            .frame(height: Theme.Size.button)
                            .surface(.clear, .pillOutline, in: Capsule())
                            .contentShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
                .disabled(session.isRunning)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Theme.Space.x12)
        .surface(done ? .clear : Theme.Colors.background, done ? .outline : card.disagrees ? .disagreeCard : .inboxCard, in: RoundedRectangle(cornerRadius: Theme.Radius.card))
        .opacity(done ? 0.75 : 1)
        .accessibilityElement(children: .contain)
    }

    private func openFree(_ id: String) {
        freeText = ""
        freeCard = id
    }

    /// "Something else…": the typed answer is used exactly like a tapped one.
    private func freeAnswer(lines: Int, placeholder: String, save: String, use: @escaping (String) -> Void) -> some View {
        let text = freeText.trimmingCharacters(in: .whitespacesAndNewlines)
        return VStack(alignment: .leading, spacing: Theme.Space.x6) {
            Text("Your answer, in your own words").textStyle(Theme.Text.captionBold).foregroundStyle(Theme.Colors.bodyLabel)
            TextField(placeholder, text: $freeText, axis: .vertical)
                .lineLimit(lines...8)
                .textFieldStyle(.plain)
                .textStyle(Theme.Text.body)
                .padding(.vertical, Theme.Space.x8)
                .padding(.horizontal, Theme.Space.x10)
                .surface(Theme.Colors.background, .focus, in: RoundedRectangle(cornerRadius: Theme.Radius.row))
                .accessibilityLabel("Your answer, in your own words")
            HStack(spacing: Theme.Space.x8) {
                Button(save) {
                    freeCard = nil
                    use(text)
                }
                .buttonStyle(BoardPillStyle(kind: .accent))
                .disabled(text.isEmpty)
                Button("Cancel") { freeCard = nil }
                    .buttonStyle(DesignLinkStyle())
                    .frame(height: Theme.Size.button)
            }
        }
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
