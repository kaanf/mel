import SwiftUI
import MelSpec

/// Parses off the main actor; views call this from `.task(id: text)`.
@concurrent nonisolated func parseDocument(_ text: String, kind: DocKind) async -> ([Block], DocSummary) {
    (MarkdownParser.blocks(text), MarkdownParser.summary(text, kind: kind))
}

/// Renders parsed spec blocks. Assumption actions are optional: without them callouts are read-only.
struct MarkdownBlocksView: View {
    let blocks: [Block]
    var onConfirm: ((Int) -> Void)?
    var onChange: ((Int, String) -> Void)?

    var body: some View {
        LazyVStack(alignment: .leading, spacing: 10) {
            ForEach(blocks.indices, id: \.self) { index in
                block(blocks[index])
            }
        }
    }

    @ViewBuilder
    private func block(_ block: Block) -> some View {
        switch block {
        case .heading(let level, let text):
            Text(text)
                .font(level == 1 ? .title.bold() : level == 2 ? .title2.bold() : .title3.bold())
                .padding(.top, level == 1 ? 0 : 8)
                .accessibilityAddTraits(.isHeader)
        case .paragraph(let text):
            Text(inline(text))
        case .criterion(let id, let text):
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(id)
                    .font(.callout.monospacedDigit())
                    .foregroundStyle(.secondary)
                Text(ears(text))
            }
        case .task(let id, let text, let done, let covers):
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Image(systemName: done ? "checkmark.square" : "square")
                    .foregroundStyle(.secondary)
                    .accessibilityLabel(done ? "Done" : "Not done")
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(Text(id).foregroundStyle(.secondary))  \(inline(text))")
                    if !covers.isEmpty {
                        Text("Covers \(covers.joined(separator: ", "))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        case .listItem(let text):
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("•").accessibilityHidden(true)
                Text(inline(text))
            }
        case .assumption(let index, let text):
            if let onConfirm, let onChange {
                CalloutView(text: text, onChange: { onChange(index, text) }, onConfirm: { onConfirm(index) })
            } else {
                CalloutView(text: text)
            }
        case .code(let text):
            Text(text)
                .font(.callout.monospaced())
                .textSelection(.enabled)
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.quinary, in: .rect(cornerRadius: 6))
        }
    }

    private func inline(_ text: String) -> AttributedString {
        (try? AttributedString(markdown: text)) ?? AttributedString(text)
    }

    private static let earsKeywords: Set<Substring> = ["WHEN", "WHILE", "IF", "THEN", "WHERE", "THE", "SHALL"]

    /// Bolds the EARS keywords (WHEN, THE … SHALL) in an acceptance criterion.
    private func ears(_ text: String) -> AttributedString {
        var result = AttributedString()
        for (offset, word) in text.split(separator: " ", omittingEmptySubsequences: false).enumerated() {
            if offset > 0 { result += AttributedString(" ") }
            var piece = AttributedString(word)
            if Self.earsKeywords.contains(word.trimmingCharacters(in: .punctuationCharacters)[...]) {
                piece.font = .body.bold()
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
        case .requirements: "\(count(stories, "story", "stories")), \(count(criteria, "acceptance criterion", "acceptance criteria"))."
        case .design: "\(count(sections, "section", "sections"))."
        case .tasks: "\(count(tasks, "task", "tasks")), each linked to criteria."
        }
    }

    private func count(_ n: Int, _ one: String, _ many: String) -> String {
        "\(n) \(n == 1 ? one : many)"
    }
}

#Preview("Requirements") {
    ScrollView {
        MarkdownBlocksView(blocks: PreviewData.requirementsBlocks, onConfirm: { _ in }, onChange: { _, _ in })
            .padding(24)
    }
    .frame(width: 620, height: 700)
}

#Preview("Read only") {
    ScrollView {
        MarkdownBlocksView(blocks: PreviewData.requirementsBlocks)
            .padding(24)
    }
    .frame(width: 360, height: 600)
}
