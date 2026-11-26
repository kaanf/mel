import SwiftUI
import UniformTypeIdentifiers
import MelSpec

/// Tell Mel (V2-2, under the center): one request at a time against the current files, with the
/// result line (V2-4) or the unplaced offer (V2-7) above the box.
struct BoardTell: View {
    let session: SpecSession

    @State private var text = ""
    @State private var files: [URL] = []
    @State private var isAttaching = false

    private var spec: Spec { session.spec }
    private var request: String { text.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var canSend: Bool { !request.isEmpty && !session.isRunning && spec.unplacedChange == nil }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.x8) {
            if let unplaced = spec.unplacedChange {
                unplacedBanner(unplaced)
            } else if let change = session.lastChange {
                result(change)
            }
            box
        }
        .fileImporter(isPresented: $isAttaching, allowedContentTypes: [.item], allowsMultipleSelection: true) { result in
            if case .success(let urls) = result { files += urls.filter { !files.contains($0) } }
        }
    }

    private func result(_ change: SpecSession.ChangeResult) -> some View {
        HStack(spacing: Theme.Space.x10) {
            DesignIcon(glyph: .check, size: Theme.Size.checkIcon, weight: 2.2).foregroundStyle(Theme.Colors.success)
            VStack(alignment: .leading, spacing: Theme.Space.x2) {
                Text(change.line).textStyle(Theme.Text.bodyBold)
                Text((change.passages.isEmpty ? "" : "Highlighted in the files. ") + "Saved to DECISIONS.md." + (change.tokens > 0 ? " \(TokenStep.text(change.tokens)) tokens." : ""))
                    .textStyle(Theme.Text.captionLoose)
                    .foregroundStyle(Theme.Colors.bodyLabel)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Button("Undo") { session.undoChange() }
                .buttonStyle(BoardPillStyle())
                .disabled(session.isRunning)
            Button { session.dismissChange() } label: {
                DesignIcon(glyph: .close, size: Theme.Size.readyCheck, weight: 2)
                    .foregroundStyle(Theme.Colors.secondaryLabel)
                    .frame(width: Theme.Size.buttonMini, height: Theme.Size.buttonMini)
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Dismiss")
        }
        .padding(.vertical, Theme.Space.x10)
        .padding(.horizontal, Theme.Space.x12)
        .surface(Theme.Colors.resultFill, .result, in: RoundedRectangle(cornerRadius: Theme.Radius.card))
        .accessibilityElement(children: .contain)
    }

    /// V2-7: nothing was changed. A whole-file rewrite only ever starts from this button.
    private func unplacedBanner(_ unplaced: UnplacedChange) -> some View {
        let file = unplaced.files.first
        let cost = file.flatMap { spec.tokens?[TokenStep(file: $0)] }
        return VStack(alignment: .leading, spacing: Theme.Space.x8) {
            Text("Mel couldn’t find where this goes in \(file?.fileName ?? "the files").")
                .textStyle(Theme.Text.bodyBold)
                .foregroundStyle(Theme.Colors.bannerTitle)
            Text((unplaced.answers ? "Your answers don’t" : "“\(unplaced.request)” doesn’t") + " fit a single passage there. Nothing was changed.")
                .textStyle(Theme.Text.calloutLoose)
                .foregroundStyle(Theme.Colors.bodyLabel)
            HStack(spacing: Theme.Space.x8) {
                Button { Task { await session.rewriteUnplaced() } } label: {
                    HStack(spacing: Theme.Space.x6) {
                        Text("Rewrite \(file?.fileName ?? "")")
                        if let cost {
                            Text("about \(TokenStep.text(cost)) tokens").textStyle(Theme.Text.caption).foregroundStyle(Theme.Colors.secondaryLabel)
                        }
                    }
                }
                .buttonStyle(BoardPillStyle())
                Button("Cancel") { Task { text = await session.cancelUnplaced() } }
                    .buttonStyle(BoardPillStyle())
            }
            .disabled(session.isRunning)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, Theme.Space.x12)
        .padding(.horizontal, Theme.Space.x14)
        .surface(Theme.Colors.bannerFill, .banner, in: RoundedRectangle(cornerRadius: Theme.Radius.card))
    }

    private var box: some View {
        VStack(alignment: .leading, spacing: Theme.Space.x8) {
            Text("Tell Mel").textStyle(Theme.Text.captionBold).foregroundStyle(Theme.Colors.bodyLabel)
            TextField("Tell Mel what to change, add or remove…", text: $text, axis: .vertical)
                .lineLimit(Theme.Size.tellLines...8)
                .textFieldStyle(.plain)
                .textStyle(Theme.Text.bodyLoose)
                .accessibilityLabel("Tell Mel")
            if !files.isEmpty {
                FlowLayout(spacing: Theme.Space.x6) {
                    ForEach(files, id: \.self) { file in
                        HStack(spacing: Theme.Space.x6) {
                            Text(file.lastPathComponent).textStyle(Theme.Text.caption)
                            Button { files.removeAll { $0 == file } } label: {
                                DesignIcon(glyph: .close, size: Theme.Size.removeIcon, weight: 2.4)
                                    .foregroundStyle(Theme.Colors.secondaryLabel)
                                    .frame(width: Theme.Size.removeButton, height: Theme.Size.removeButton)
                                    .contentShape(Circle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Remove \(file.lastPathComponent)")
                        }
                        .padding(.leading, Theme.Space.x8)
                        .padding(.trailing, Theme.Space.x4)
                        .frame(height: Theme.Size.buttonMini)
                        .background(Theme.Colors.fill, in: RoundedRectangle(cornerRadius: Theme.Radius.code))
                    }
                }
            }
            HStack(spacing: Theme.Space.x8) {
                Button { isAttaching = true } label: {
                    HStack(spacing: Theme.Space.x5) {
                        DesignIcon(glyph: .attach, size: Theme.Size.smallCheck)
                        Text("Attach")
                    }
                }
                .buttonStyle(BoardPillStyle(kind: .quiet, height: Theme.Size.buttonSmall, padding: Theme.Space.x10))
                Text("One request at a time. Mel edits only the passages it touches and logs why in DECISIONS.md.")
                    .textStyle(Theme.Text.caption)
                    .foregroundStyle(Theme.Colors.secondaryLabel)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Button(session.isRunning ? "Placing…" : "Send") {
                    let (sent, attached) = (request, files)
                    Task {
                        // The request stays in the box until the run has finished.
                        if await session.tell(sent, files: attached), text.trimmingCharacters(in: .whitespacesAndNewlines) == sent {
                            text = ""
                            files = []
                        }
                    }
                }
                .buttonStyle(BoardPillStyle(kind: .accent, padding: Theme.Space.x14))
                .disabled(!canSend)
                .keyboardShortcut(.return, modifiers: .command)
            }
        }
        .padding(.vertical, Theme.Space.x10)
        .padding(.horizontal, Theme.Space.x12)
        .surface(Theme.Colors.background, .storyCard, in: RoundedRectangle(cornerRadius: Theme.Radius.card))
    }
}
