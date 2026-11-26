import SwiftUI
import MelSpec

/// Parses off the main actor; views call this from `.task(id: text)`.
@concurrent nonisolated func parseDocument(_ text: String, kind: DocKind) async -> ([Block], DocSummary) {
    (MarkdownParser.blocks(text), MarkdownParser.summary(text, kind: kind))
}

/// Renders parsed spec blocks as the B4 article: title, stories with priority badges, EARS criteria,
/// assumption and open-question boxes, the MVP line. Actions are optional: without them boxes are read-only.
struct MarkdownBlocksView: View {
    let blocks: [Block]
    var onConfirm: ((Int) -> Void)?
    var onChange: ((Int, String) -> Void)?
    var onAnswer: ((Int, String) -> Void)?
    /// EXPERIENCE.md (B5): numbered steps draw as a flow diagram with their branches; the screens table as state chips.
    var isExperience = false
    /// Board (V2-4): passages the last change wrote. Blocks that hold one get the blue ground.
    var highlights: [String] = []

    /// Blocks grouped the way the article draws them: runs of criteria and list items share one list.
    private enum Item {
        case heading(level: Int, text: String, priority: String?)
        case paragraph(String)
        case source(String)
        case criteria([(id: String, text: String)])
        case bullets([String])
        case ordered([(number: Int, text: String)])
        case tasks([(id: String, text: String, done: Bool, covers: [String], details: [String])])
        case assumption(index: Int, text: String)
        case openQuestion(index: Int, text: String)
        case covers([String])
        case mvpLine
        case table(header: [String], rows: [[String]])
        case code(String)
        case flow(steps: [String], branches: [String])
        case states(rows: [[String]])
    }

    private var items: [Item] {
        var items: [Item] = []
        for block in blocks {
            switch (block, items.last) {
            case (.orderedItem(_, let text), .flow(let steps, let branches)?) where isExperience && branches.isEmpty:
                items[items.count - 1] = .flow(steps: steps + [text], branches: [])
            case (.orderedItem(_, let text), _) where isExperience:
                items.append(.flow(steps: [text], branches: []))
            case (.listItem(let text), .flow(let steps, let branches)?) where isExperience:
                items[items.count - 1] = .flow(steps: steps, branches: branches + [text])
            case (.table(let header, let rows), _) where isExperience && header.count == 3 && header[1] == "States":
                items.append(.states(rows: rows))
            case (.criterion(let id, let text), .criteria(let list)?):
                items[items.count - 1] = .criteria(list + [(id, text)])
            case (.criterion(let id, let text), _):
                items.append(.criteria([(id, text)]))
            // A task's sub-items (`Priority:`, `Reads:`, `Verify:`) sit under its title.
            case (.listItem(let text), .tasks(var list)?):
                list[list.count - 1].details.append(text)
                items[items.count - 1] = .tasks(list)
            case (.listItem(let text), .bullets(let list)?):
                items[items.count - 1] = .bullets(list + [text])
            case (.listItem(let text), _):
                items.append(.bullets([text]))
            case (.orderedItem(let n, let text), .ordered(let list)?):
                items[items.count - 1] = .ordered(list + [(n, text)])
            case (.orderedItem(let n, let text), _):
                items.append(.ordered([(n, text)]))
            case (.task(let id, let text, let done, let covers), .tasks(let list)?):
                items[items.count - 1] = .tasks(list + [(id, text, done, covers, [])])
            case (.task(let id, let text, let done, let covers), _):
                items.append(.tasks([(id, text, done, covers, [])]))
            // A story's `P1 · MVP` line becomes a badge after its heading.
            case (.priority(let priority, let mvp), .heading(let level, let text, nil)?):
                items[items.count - 1] = .heading(level: level, text: text, priority: mvp ? "\(priority) · MVP" : priority)
            case (.priority(let priority, let mvp), _):
                items.append(.source(mvp ? "\(priority) · MVP" : priority))
            case (.heading(let level, let text), _): items.append(.heading(level: level, text: text, priority: nil))
            case (.paragraph(let text), _): items.append(.paragraph(text))
            case (.source(let text), _): items.append(.source("Source: \(text)"))
            case (.assumption(let index, let text), _): items.append(.assumption(index: index, text: text))
            case (.openQuestion(let index, let text), _): items.append(.openQuestion(index: index, text: text))
            case (.covers(let ids), _): items.append(.covers(ids))
            case (.mvpLine, _): items.append(.mvpLine)
            case (.table(let header, let rows), _): items.append(.table(header: header, rows: rows))
            case (.code(let text), _): items.append(.code(text))
            }
        }
        return items
    }

    var body: some View {
        let items = items
        LazyVStack(alignment: .leading, spacing: Theme.Space.x14) {
            ForEach(items.indices, id: \.self) { index in
                if isChanged(items[index]) {
                    item(items[index], isFirst: index == 0)
                        .padding(.vertical, Theme.Space.x2)
                        .padding(.horizontal, Theme.Space.x8)
                        .background(Theme.Colors.changedFill, in: RoundedRectangle(cornerRadius: Theme.Radius.code))
                        .padding(.horizontal, -Theme.Space.x8)
                } else {
                    item(items[index], isFirst: index == 0)
                }
            }
        }
        .foregroundStyle(Theme.Colors.label)
    }

    /// The lines of the changed passages without their Markdown markers, as a block's text has them.
    private var changedLines: [String] {
        highlights.flatMap { $0.split(whereSeparator: \.isNewline) }.compactMap { line in
            var text = line.drop { "#->|\t ".contains($0) }
            for box in ["[ ] ", "[x] "] where text.hasPrefix(box) { text = text.dropFirst(box.count) }
            return text.count < 4 ? nil : String(text)
        }
    }

    private func isChanged(_ item: Item) -> Bool {
        guard !highlights.isEmpty else { return false }
        let text: String = switch item {
        case .heading(_, let text, _), .paragraph(let text), .source(let text), .code(let text), .assumption(_, let text), .openQuestion(_, let text): text
        case .criteria(let list): list.map { "\($0.id) \($0.text)" }.joined(separator: "\n")
        case .bullets(let list): list.joined(separator: "\n")
        case .ordered(let list): list.map(\.text).joined(separator: "\n")
        case .tasks(let list): list.map { "\($0.id). \($0.text)\n" + $0.details.joined(separator: "\n") }.joined(separator: "\n")
        case .covers(let ids): "Covers: " + ids.joined(separator: ", ")
        case .table(_, let rows), .states(let rows): rows.map { $0.joined(separator: " | ") }.joined(separator: "\n")
        case .flow(let steps, let branches): (steps + branches).joined(separator: "\n")
        case .mvpLine: ""
        }
        return changedLines.contains { text.contains($0) }
    }

    @ViewBuilder
    private func item(_ item: Item, isFirst: Bool) -> some View {
        switch item {
        case .heading(let level, let text, let priority):
            if level == 1 {
                Text(text).textStyle(Theme.Text.title2).accessibilityAddTraits(.isHeader)
            } else {
                HStack(spacing: Theme.Space.x8) {
                    Text(inline(text)).textStyle(Theme.Text.headline)
                    if let priority {
                        Text(priority)
                            .textStyle(Theme.Text.captionBold)
                            .padding(.horizontal, Theme.Space.x7)
                            .frame(height: Theme.Size.badge)
                            .background(Theme.Colors.badgeFill, in: Capsule())
                    }
                }
                .padding(.top, isFirst ? 0 : Theme.Space.x10)
                .accessibilityElement(children: .combine)
                .accessibilityAddTraits(.isHeader)
            }
        case .paragraph(let text):
            Text(inline(text)).textStyle(Theme.Text.prose)
        case .source(let text):
            Text(text).textStyle(Theme.Text.caption).foregroundStyle(Theme.Colors.secondaryLabel)
        case .criteria(let list):
            VStack(alignment: .leading, spacing: Theme.Space.x8) {
                ForEach(list.indices, id: \.self) { i in
                    HStack(alignment: .firstTextBaseline, spacing: Theme.Space.x12) {
                        Text(list[i].id)
                            .textStyle(Theme.Text.codeProse)
                            .foregroundStyle(Theme.Colors.secondaryLabel)
                            .frame(width: Theme.Size.criterionID, alignment: .leading)
                        Text(Self.ears(list[i].text)).textStyle(Theme.Text.prose)
                    }
                    .accessibilityElement(children: .combine)
                }
            }
        case .bullets(let list):
            VStack(alignment: .leading, spacing: Theme.Space.x4) {
                ForEach(list.indices, id: \.self) { i in
                    HStack(alignment: .firstTextBaseline, spacing: 0) {
                        Text("•").frame(width: Theme.Space.x18, alignment: .leading).accessibilityHidden(true)
                        Text(inline(list[i]))
                    }
                    .textStyle(Theme.Text.prose)
                }
            }
        case .ordered(let list):
            VStack(alignment: .leading, spacing: Theme.Space.x4) {
                ForEach(list.indices, id: \.self) { i in
                    HStack(alignment: .firstTextBaseline, spacing: 0) {
                        Text("\(list[i].number).").monospacedDigit().foregroundStyle(Theme.Colors.secondaryLabel)
                            .frame(width: Theme.Space.x18 + Theme.Space.x6, alignment: .leading)
                        Text(inline(list[i].text))
                    }
                    .textStyle(Theme.Text.prose)
                }
            }
        case .tasks(let list):
            VStack(alignment: .leading, spacing: Theme.Space.x8) {
                ForEach(list.indices, id: \.self) { i in
                    let task = list[i]
                    HStack(alignment: .firstTextBaseline, spacing: Theme.Space.x12) {
                        Text(task.id)
                            .textStyle(Theme.Text.codeProse)
                            .foregroundStyle(Theme.Colors.secondaryLabel)
                            .frame(width: Theme.Size.criterionID, alignment: .leading)
                        VStack(alignment: .leading, spacing: Theme.Space.x2) {
                            Text(inline(task.text)).textStyle(Theme.Text.prose)
                            if !task.covers.isEmpty {
                                Text("Covers \(task.covers.joined(separator: ", "))")
                                    .textStyle(Theme.Text.caption)
                                    .foregroundStyle(Theme.Colors.secondaryLabel)
                            }
                            ForEach(task.details.indices, id: \.self) { d in
                                Text(inline(task.details[d]))
                                    .textStyle(Theme.Text.caption)
                                    .foregroundStyle(Theme.Colors.secondaryLabel)
                            }
                        }
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityValue(task.done ? "Done" : "")
                }
            }
        case .assumption(let index, let text):
            assumptionBox(index: index, text: text).id(Self.anchor("assumption", index, text))
        case .openQuestion(let index, let text):
            openQuestionBox(index: index, text: text).id(Self.anchor("open-question", index, text))
        case .covers(let ids):
            Text("Covers \(ids.joined(separator: ", "))").textStyle(Theme.Text.caption).foregroundStyle(Theme.Colors.secondaryLabel)
        case .mvpLine:
            HStack(spacing: Theme.Space.x10) {
                dashedLine
                Text("MVP LINE").textStyle(Theme.Text.captionBold).foregroundStyle(Theme.Colors.secondaryLabel)
                dashedLine
            }
            .padding(.top, Theme.Space.x6)
            .accessibilityElement(children: .combine)
        case .table(let header, let rows):
            Grid(alignment: .leading, horizontalSpacing: Theme.Space.x12, verticalSpacing: Theme.Space.x4) {
                GridRow { ForEach(header.indices, id: \.self) { Text(inline(header[$0])).textStyle(Theme.Text.calloutMedium) } }
                ForEach(rows.indices, id: \.self) { r in
                    GridRow { ForEach(rows[r].indices, id: \.self) { Text(inline(rows[r][$0])).textStyle(Theme.Text.callout) } }
                }
            }
        case .flow(let steps, let branches):
            flowDiagram(steps: steps, branches: branches)
        case .states(let rows):
            statesTable(rows).id("states")
        case .code(let text):
            Text(text)
                .textStyle(Theme.Text.codeBlock)
                .textSelection(.enabled)
                .padding(Theme.Space.x10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Theme.Colors.fill, in: RoundedRectangle(cornerRadius: Theme.Radius.code))
        }
    }

    /// "Schedule (1.1, 1.2)" → ("Schedule", "1.1 · 1.2").
    private static func split(_ text: String) -> (name: String, ids: String?) {
        guard text.hasSuffix(")"), let open = text.lastIndex(of: "(") else { return (text, nil) }
        let ids = text[text.index(after: open)..<text.index(before: text.endIndex)]
            .split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.joined(separator: " · ")
        return (text[..<open].trimmingCharacters(in: .whitespaces), ids)
    }

    private func flowDiagram(steps: [String], branches: [String]) -> some View {
        VStack(alignment: .leading, spacing: Theme.Space.x10) {
            FlowLayout(spacing: Theme.Space.x6) {
                ForEach(steps.indices, id: \.self) { i in
                    let step = Self.split(steps[i])
                    // The arrow leads its node, so a wrapped row starts with one instead of ending on one.
                    HStack(spacing: Theme.Space.x6) {
                        if i > 0 {
                            DesignIcon(glyph: .flowArrow, size: Theme.Size.flowArrow).foregroundStyle(Theme.Colors.secondaryLabel)
                        }
                        VStack(alignment: .leading, spacing: Theme.Space.x2) {
                            Text(step.name).textStyle(Theme.Text.calloutBold)
                            if let ids = step.ids {
                                Text(ids).textStyle(Theme.Text.codeMicro).foregroundStyle(Theme.Colors.secondaryLabel)
                            }
                        }
                        .padding(.vertical, Theme.Space.x8)
                        .padding(.horizontal, Theme.Space.x10)
                        .frame(minWidth: Theme.Size.flowNodeMin, alignment: .leading)
                        .surface(Theme.Colors.fill, .outlineLight, in: RoundedRectangle(cornerRadius: Theme.Radius.row))
                    }
                }
            }
            if !branches.isEmpty {
                VStack(alignment: .leading, spacing: Theme.Space.x6) {
                    ForEach(branches.indices, id: \.self) { i in
                        // "Class is full: Waitlist sheet (1.2)"
                        let parts = branches[i].split(separator: ":", maxSplits: 1).map { $0.trimmingCharacters(in: .whitespaces) }
                        let target = Self.split(parts.last ?? "")
                        HStack(spacing: Theme.Space.x8) {
                            DesignIcon(glyph: .branch, size: Theme.Size.settingsIcon).foregroundStyle(Theme.Colors.secondaryLabel)
                            if parts.count > 1 {
                                Text(parts[0]).textStyle(Theme.Text.callout).foregroundStyle(Theme.Colors.secondaryLabel)
                            }
                            Text(target.name)
                                .textStyle(Theme.Text.calloutBold)
                                .padding(.vertical, Theme.Space.x3)
                                .padding(.horizontal, Theme.Space.x8)
                                .background(Theme.Colors.fill, in: RoundedRectangle(cornerRadius: Theme.Radius.code))
                            if let ids = target.ids {
                                Text(ids).textStyle(Theme.Text.codeMicro).foregroundStyle(Theme.Colors.secondaryLabel)
                            }
                        }
                        .accessibilityElement(children: .combine)
                    }
                }
                .padding(.leading, Theme.Size.branchIndent)
            }
        }
        .padding(Theme.Space.x16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .surface(.clear, .outlineCard, in: RoundedRectangle(cornerRadius: Theme.Radius.card))
    }

    /// Screens and states: a `!` state is missing and drawn with a red outline.
    private func statesTable(_ rows: [[String]]) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: Theme.Space.x10) {
                Text("Screen").frame(width: Theme.Size.screenColumn, alignment: .leading)
                Text("States").frame(maxWidth: .infinity, alignment: .leading)
                Text("Criteria").frame(width: Theme.Size.criteriaColumn, alignment: .trailing)
            }
            .textStyle(Theme.Text.captionBold)
            .foregroundStyle(Theme.Colors.secondaryLabel)
            .padding(.vertical, Theme.Space.x8)
            .padding(.horizontal, Theme.Space.x12)
            .overlay(alignment: .bottom) { Rectangle().fill(Theme.Colors.separator).frame(height: Theme.Size.hairline) }
            ForEach(rows.indices, id: \.self) { r in
                let row = rows[r] + Array(repeating: "", count: max(0, 3 - rows[r].count))
                HStack(spacing: Theme.Space.x10) {
                    Text(row[0]).textStyle(Theme.Text.bodyMedium).frame(width: Theme.Size.screenColumn, alignment: .leading)
                    FlowLayout(spacing: Theme.Space.x4) {
                        ForEach(row[1].split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }, id: \.self) { state in
                            stateChip(state)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    Text(row[2].replacingOccurrences(of: ",", with: ""))
                        .textStyle(Theme.Text.codeCaption)
                        .foregroundStyle(Theme.Colors.secondaryLabel)
                        .frame(width: Theme.Size.criteriaColumn, alignment: .trailing)
                }
                .padding(.vertical, Theme.Space.x8)
                .padding(.horizontal, Theme.Space.x12)
                .overlay(alignment: .bottom) { Rectangle().fill(Theme.Colors.separatorFaint).frame(height: Theme.Size.hairline) }
                .accessibilityElement(children: .combine)
            }
        }
        .surface(.clear, .outlineCard, in: RoundedRectangle(cornerRadius: Theme.Radius.box))
    }

    @ViewBuilder
    private func stateChip(_ state: String) -> some View {
        if state.hasPrefix("!") {
            Text("\(state.dropFirst()) missing")
                .textStyle(Theme.Text.captionBold)
                .foregroundStyle(Theme.Colors.cautionText)
                .padding(.horizontal, Theme.Space.x8)
                .frame(height: Theme.Size.badge)
                .surface(Theme.Colors.background, .missingBadge, in: Capsule())
        } else {
            Text(state)
                .textStyle(Theme.Text.caption)
                .padding(.horizontal, Theme.Space.x8)
                .frame(height: Theme.Size.badge)
                .background(Theme.Colors.chipFill, in: Capsule())
        }
    }

    private var dashedLine: some View {
        Rectangle()
            .stroke(Theme.Colors.tertiary, style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
            .frame(height: 1)
            .frame(maxWidth: .infinity)
    }

    private func assumptionBox(index: Int, text: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: Theme.Space.x4) {
                HStack(spacing: Theme.Space.x6) {
                    DesignIcon(glyph: .star, size: Theme.Size.alertIcon, weight: 1.4)
                    Text("Assumption").textStyle(Theme.Text.bodyBold)
                }
                Text(inline(text)).textStyle(Theme.Text.body)
            }
            .padding(.vertical, Theme.Space.x10)
            .padding(.horizontal, Theme.Space.x12)
            if let onConfirm, let onChange {
                Rectangle().fill(Theme.Colors.separator).frame(height: Theme.Size.hairline).padding(.leading, Theme.Space.x12)
                HStack(spacing: Theme.Space.x8) {
                    Spacer()
                    Button("Change…") { onChange(index, text) }
                        .buttonStyle(DesignButtonStyle(role: .secondary, height: Theme.Size.buttonMini, leading: Theme.Space.x12, trailing: Theme.Space.x12, text: Theme.Text.callout))
                    Button("Confirm") { onConfirm(index) }
                        .buttonStyle(DesignButtonStyle(role: .secondary, height: Theme.Size.buttonMini, leading: Theme.Space.x12, trailing: Theme.Space.x12, text: Theme.Text.calloutMedium))
                }
                .padding(.vertical, Theme.Space.x8)
                .padding(.horizontal, Theme.Space.x12)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.Colors.fill, in: RoundedRectangle(cornerRadius: Theme.Radius.box))
    }

    private func openQuestionBox(index: Int, text: String) -> some View {
        VStack(alignment: .leading, spacing: Theme.Space.x4) {
            HStack(spacing: Theme.Space.x6) {
                DesignIcon(glyph: .question, size: Theme.Size.alertIcon)
                Text("Open Question").textStyle(Theme.Text.bodyBold).frame(maxWidth: .infinity, alignment: .leading)
                Text("Left for later").textStyle(Theme.Text.caption).foregroundStyle(Theme.Colors.secondaryLabel)
            }
            Text(inline(text)).textStyle(Theme.Text.body)
            if let onAnswer {
                Button("Answer Now…") { onAnswer(index, text) }
                    .buttonStyle(DesignLinkStyle(text: Theme.Text.body))
            }
        }
        .padding(.vertical, Theme.Space.x10)
        .padding(.horizontal, Theme.Space.x12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .surface(.clear, .outlineStrong, in: RoundedRectangle(cornerRadius: Theme.Radius.box))
    }

    /// A box's scroll anchor. It includes the text: after a confirm the next boxes' indexes shift down, and an
    /// index-only id made the lazy stack reuse the confirmed box's view for them.
    static func anchor(_ prefix: String, _ index: Int, _ text: String) -> String { "\(prefix)-\(index)-\(text)" }

    private func inline(_ text: String) -> AttributedString { Self.inline(text) }

    /// Bold, italic, `code` and links in one line of spec text (Review, Live Preview, B7).
    static func inline(_ text: String) -> AttributedString {
        // Inline only: block syntax is already parsed, and "1. Book a class" must keep its number.
        (try? AttributedString(markdown: text, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace))) ?? AttributedString(text)
    }

    private static let earsKeywords: Set<Substring> = ["WHEN", "WHILE", "IF", "THEN", "WHERE"]

    /// Bolds the EARS keywords of a criterion (WHEN, IF … THEN, and the whole "THE <system> SHALL").
    static func ears(_ text: String) -> AttributedString {
        let words = text.split(separator: " ", omittingEmptySubsequences: false)
        let bare = words.map { $0.trimmingCharacters(in: .punctuationCharacters)[...] }
        // "THE … SHALL": from the first THE that a SHALL follows, through that SHALL.
        var span: ClosedRange<Int>?
        if let shall = bare.firstIndex(of: "SHALL"), let the = bare[..<shall].lastIndex(of: "THE") { span = the...shall }
        var result = AttributedString()
        for (offset, word) in words.enumerated() {
            if offset > 0 { result += AttributedString(" ") }
            var piece = AttributedString(word)
            if earsKeywords.contains(bare[offset]) || span?.contains(offset) == true {
                piece.font = Theme.Text.bodyBold.font
            }
            result += piece
        }
        return result
    }
}

extension DocSummary {
    /// "5 stories, 14 acceptance criteria." and friends.
    func line(for kind: DocKind) -> String {
        switch kind {
        case .product: "Problem, users and scope."
        case .requirements: "\(count(stories, "story", "stories")) (\(mvpStories) in the MVP), \(count(criteria, "acceptance criterion", "acceptance criteria")), \(count(quality, "quality requirement", "quality requirements"))."
        case .experience: "\(count(flows, "flow", "flows")), \(count(screens, "screen", "screens"))."
        case .architecture, .spec: "\(count(sections, "section", "sections"))."
        case .tasks: "\(count(tasks, "task", "tasks")), each linked to criteria."
        }
    }

    private func count(_ n: Int, _ one: String, _ many: String) -> String {
        "\(n) \(n == 1 ? one : many)"
    }
}

#Preview("Requirements") {
    ScrollView {
        MarkdownBlocksView(blocks: PreviewData.requirementsBlocks, onConfirm: { _ in }, onChange: { _, _ in }, onAnswer: { _, _ in })
            .padding(Theme.Space.x24)
    }
    .frame(width: 620, height: 700)
    .background(Theme.Colors.background)
}

#Preview("Read only") {
    ScrollView {
        MarkdownBlocksView(blocks: PreviewData.requirementsBlocks)
            .padding(Theme.Space.x24)
    }
    .frame(width: 360, height: 600)
    .background(Theme.Colors.background)
}
