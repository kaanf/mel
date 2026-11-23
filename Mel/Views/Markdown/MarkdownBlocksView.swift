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

    /// Blocks grouped the way the article draws them: runs of criteria and list items share one list.
    private enum Item {
        case heading(level: Int, text: String, priority: String?)
        case paragraph(String)
        case source(String)
        case criteria([(id: String, text: String)])
        case bullets([String])
        case ordered([(number: Int, text: String)])
        case tasks([(id: String, text: String, done: Bool, covers: [String])])
        case assumption(index: Int, text: String)
        case openQuestion(index: Int, text: String)
        case covers([String])
        case mvpLine
        case table(header: [String], rows: [[String]])
        case code(String)
    }

    private var items: [Item] {
        var items: [Item] = []
        for block in blocks {
            switch (block, items.last) {
            case (.criterion(let id, let text), .criteria(let list)?):
                items[items.count - 1] = .criteria(list + [(id, text)])
            case (.criterion(let id, let text), _):
                items.append(.criteria([(id, text)]))
            case (.listItem(let text), .bullets(let list)?):
                items[items.count - 1] = .bullets(list + [text])
            case (.listItem(let text), _):
                items.append(.bullets([text]))
            case (.orderedItem(let n, let text), .ordered(let list)?):
                items[items.count - 1] = .ordered(list + [(n, text)])
            case (.orderedItem(let n, let text), _):
                items.append(.ordered([(n, text)]))
            case (.task(let id, let text, let done, let covers), .tasks(let list)?):
                items[items.count - 1] = .tasks(list + [(id, text, done, covers)])
            case (.task(let id, let text, let done, let covers), _):
                items.append(.tasks([(id, text, done, covers)]))
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
                item(items[index], isFirst: index == 0)
            }
        }
        .foregroundStyle(Theme.Colors.label)
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
                        }
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityValue(task.done ? "Done" : "")
                }
            }
        case .assumption(let index, let text):
            assumptionBox(index: index, text: text).id("assumption-\(index)")
        case .openQuestion(let index, let text):
            openQuestionBox(index: index, text: text).id("open-question-\(index)")
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
        case .code(let text):
            Text(text)
                .textStyle(Theme.Text.codeBlock)
                .textSelection(.enabled)
                .padding(Theme.Space.x10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Theme.Colors.fill, in: RoundedRectangle(cornerRadius: Theme.Radius.code))
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

    private func inline(_ text: String) -> AttributedString {
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
        case .experience, .architecture, .spec: "\(count(sections, "section", "sections"))."
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
