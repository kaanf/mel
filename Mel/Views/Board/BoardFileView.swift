import SwiftUI
import MelSpec

/// V2-4: a file open in the board's center. Formatted or Markdown, Open in Editor, Reveal in
/// Finder, Edit. A file still being written and DECISIONS.md are read-only.
struct BoardFileView: View {
    let session: SpecSession
    let file: BoardFile
    @Binding var isEditing: Bool
    let close: () -> Void

    @State private var showsMarkdown = false
    @State private var draft = ""
    @State private var blocks: [Block] = []

    private var spec: Spec { session.spec }

    private var kind: DocKind? { if case .doc(let kind) = file { kind } else { nil } }
    private var state: FileState { kind.map(spec.fileState) ?? .ready }
    private var isWriting: Bool { kind.map { spec.docs[$0] == .writing } ?? false }
    private var notYet: Bool { state == .waiting }
    private var text: String { kind.map { isWriting ? session.liveText : session.documents[$0] ?? "" } ?? "" }
    private var passages: [String] { kind.flatMap { session.lastChange?.passages[$0] } ?? [] }

    private var readOnlyText: String? {
        guard let kind else { return "Mel keeps this log. Change a decision from its card; restore a removed story here." }
        if notYet {
            return "Not written yet. " + (spec.gate?.file == kind ? "It starts after \(BoardStatus.answers(spec.gate?.answers ?? 0))." : "It starts after the files before it.")
        }
        return isWriting ? "Mel is still writing this file. You can read it now; Edit opens when it’s ready." : nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.x12) {
            header
            if let readOnlyText {
                Text(readOnlyText).textStyle(Theme.Text.callout).foregroundStyle(Theme.Colors.secondaryLabel)
            }
            if let kind, !notYet {
                if isEditing {
                    editor(kind)
                } else if showsMarkdown {
                    Text(Self.highlighted(text, passages))
                        .textStyle(Theme.Text.codeDiff)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, Theme.Space.x16)
                        .padding(.horizontal, Theme.Space.x18)
                        .background(Theme.Colors.fill, in: RoundedRectangle(cornerRadius: Theme.Radius.card))
                } else {
                    MarkdownBlocksView(blocks: blocks, isExperience: kind == .experience, highlights: passages)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, Theme.Space.x20)
                        .padding(.horizontal, Theme.Space.x24)
                        .surface(Theme.Colors.background, .article, in: RoundedRectangle(cornerRadius: Theme.Radius.card))
                }
            } else if kind == nil {
                decisions
            }
        }
        .task(id: text) { blocks = await parseDocument(text, kind: kind ?? .product).0 }
    }

    private var header: some View {
        HStack(spacing: Theme.Space.x8) {
            Button(action: close) {
                HStack(spacing: Theme.Space.x4) {
                    DesignIcon(glyph: .chevronLeft, size: Theme.Size.readyCheck)
                    Text("Plan")
                }
                .padding(.leading, -Theme.Space.x6)
            }
            .buttonStyle(BoardPillStyle(kind: .quiet))
            Text("›").textStyle(Theme.Text.callout).foregroundStyle(Theme.Colors.tertiary)
            Text(file.name).textStyle(Theme.Text.codeBold)
            if kind != nil {
                FileStateDot(state: state)
                Text(spec.gate?.file == kind ? "Starts after \(BoardStatus.answers(spec.gate?.answers ?? 0))" : state.word)
                    .textStyle(Theme.Text.caption)
                    .foregroundStyle(Theme.Colors.secondaryLabel)
            }
            Spacer(minLength: 0)
            if let kind, !notYet {
                HStack(spacing: Theme.Space.x2) {
                    Button("Formatted") { showsMarkdown = false; isEditing = false }
                        .buttonStyle(BoardSegmentStyle(isSelected: !showsMarkdown, text: showsMarkdown ? Theme.Text.callout : Theme.Text.calloutBold))
                    Button("Markdown") { showsMarkdown = true; isEditing = false }
                        .buttonStyle(BoardSegmentStyle(isSelected: showsMarkdown, text: showsMarkdown ? Theme.Text.calloutBold : Theme.Text.callout))
                }
                .padding(Theme.Space.x2)
                .background(Theme.Colors.badgeFill, in: Capsule())
                Button("Open in Editor") { session.openInEditor(kind) }
                    .buttonStyle(BoardPillStyle(kind: .quiet, padding: Theme.Space.x10))
                Button { session.showInFinder(kind) } label: {
                    DesignIcon(glyph: .folderOpen, size: Theme.Size.paperclipIcon)
                        .foregroundStyle(Theme.Colors.bodyLabel)
                        .frame(width: Theme.Size.button, height: Theme.Size.button)
                        .background(Theme.Colors.chipFill, in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Reveal in Finder")
                .help("Reveal in Finder")
                if !isEditing, !isWriting, !session.isRunning {
                    Button("Edit") {
                        draft = text
                        isEditing = true
                    }
                    .buttonStyle(BoardPillStyle(elevation: .editButton))
                }
            }
        }
    }

    private func editor(_ kind: DocKind) -> some View {
        VStack(alignment: .leading, spacing: Theme.Space.x8) {
            Text("Editing \(kind.fileName). Your edits are never overwritten by the agent.")
                .textStyle(Theme.Text.callout)
                .foregroundStyle(Theme.Colors.bodyLabel)
            TextEditor(text: $draft)
                .font(Theme.Text.codeDiff.font)
                .scrollContentBackground(.hidden)
                .padding(.vertical, Theme.Space.x14)
                .padding(.horizontal, Theme.Space.x12)
                .frame(minHeight: CGFloat(Theme.Size.editorLines) * 19 + 2 * Theme.Space.x14)
                .surface(Theme.Colors.background, .focus, in: RoundedRectangle(cornerRadius: Theme.Radius.card))
                .accessibilityLabel("Editing \(kind.fileName)")
            HStack(spacing: Theme.Space.x8) {
                Button("Save") {
                    session.save(draft, for: kind)
                    isEditing = false
                }
                .buttonStyle(DesignButtonStyle(height: Theme.Size.chip, leading: Theme.Space.x14, trailing: Theme.Space.x14, elevation: .init()))
                .keyboardShortcut("s", modifiers: .command)
                Button("Cancel") { isEditing = false }
                    .buttonStyle(BoardPillStyle(kind: .quiet, height: Theme.Size.chip, padding: Theme.Space.x14))
                    .keyboardShortcut(.cancelAction)
            }
        }
    }

    /// DECISIONS.md: every answer and change with its reason, newest first, and Restore for removed stories.
    private var decisions: some View {
        VStack(alignment: .leading, spacing: Theme.Space.x8) {
            Text("Decisions").textStyle(Theme.Text.fileTitle).padding(.bottom, Theme.Space.x4)
            Text("Every answer and change, with the reason. Agents read this before they change the plan.")
                .textStyle(Theme.Text.prose)
                .foregroundStyle(Theme.Colors.bodyLabel)
            ForEach(spec.removedStories ?? []) { removed in
                HStack(spacing: Theme.Space.x8) {
                    Text("•").foregroundStyle(Theme.Colors.tertiary)
                    Text("Removed: \(removed.title) (and what was built on it)")
                        .textStyle(Theme.Text.prose)
                        .foregroundStyle(Theme.Colors.secondaryLabel)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Button("Restore") { Task { await session.restoreStory(removed.id) } }
                        .buttonStyle(BoardPillStyle(height: Theme.Size.buttonMini, padding: Theme.Space.x10))
                        .disabled(session.isRunning)
                }
                .padding(.leading, Theme.Space.x4)
            }
            ForEach(session.decisions) { decision in
                HStack(alignment: .firstTextBaseline, spacing: Theme.Space.x8) {
                    Text("•").foregroundStyle(Theme.Colors.tertiary)
                    Text("\(decision.id) \(decision.title)" + (decision.reason.isEmpty ? "" : ": \(decision.reason)") + " (\(decision.source))")
                        .textStyle(Theme.Text.prose)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.leading, Theme.Space.x4)
            }
            if session.decisions.isEmpty {
                Text("Nothing decided yet.").textStyle(Theme.Text.prose).foregroundStyle(Theme.Colors.secondaryLabel)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, Theme.Space.x20)
        .padding(.horizontal, Theme.Space.x24)
        .surface(Theme.Colors.background, .article, in: RoundedRectangle(cornerRadius: Theme.Radius.card))
    }

    /// The file's Markdown with the last change's passages on a blue ground.
    static func highlighted(_ text: String, _ passages: [String]) -> AttributedString {
        var result = AttributedString(text)
        for passage in passages where !passage.isEmpty {
            var from = result.startIndex
            while let range = result[from...].range(of: passage) {
                result[range].backgroundColor = Theme.Colors.changedFill
                from = range.upperBound
            }
        }
        return result
    }
}

#Preview("File, change highlighted") {
    @Previewable @State var isEditing = false
    BoardFileView(session: PreviewData.boardChangedSession, file: .doc(.requirements), isEditing: $isEditing) {}
        .padding()
        .frame(width: 820)
}

#Preview("Decisions") {
    @Previewable @State var isEditing = false
    BoardFileView(session: PreviewData.boardSession, file: .decisions, isEditing: $isEditing) {}
        .padding()
        .frame(width: 820)
}
