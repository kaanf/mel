import SwiftUI
import MelSpec

/// Handoff after the last approval: file summaries, the start command, optional Git commit.
struct SpecReadySheet: View {
    let session: SpecSession
    @Environment(AppState.self) private var state
    @Environment(\.dismiss) private var dismiss
    @State private var commitToGit = false
    @State private var copied = false
    @State private var error: String?
    @State private var summaries: [DocKind: DocSummary] = [:]

    private var spec: Spec { session.spec }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label {
                Text("Spec ready").font(.title2.bold())
            } icon: {
                Image(systemName: "checkmark.seal.fill").foregroundStyle(.green)
            }
            Text("All four files are approved and saved as plain Markdown. Any coding agent can build from them.")
                .foregroundStyle(.secondary)
            GroupBox {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(DocKind.allCases, id: \.self) { kind in
                        Label {
                            VStack(alignment: .leading, spacing: 1) {
                                Text(kind.fileName)
                                Text((summaries[kind] ?? DocSummary()).line(for: kind))
                                    .font(.callout)
                                    .foregroundStyle(.secondary)
                            }
                        } icon: {
                            Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            VStack(alignment: .leading, spacing: 6) {
                Text("Start building").font(.headline)
                Text("Run this in the project folder. It points the agent at your spec.")
                    .foregroundStyle(.secondary)
                HStack {
                    Text(session.startCommand)
                        .font(.callout.monospaced())
                        .textSelection(.enabled)
                    Spacer()
                    Button(copied ? "Copied" : "Copy") {
                        state.copy(session.startCommand)
                        copied = true
                    }
                }
                .padding(8)
                .background(.quinary, in: .rect(cornerRadius: 6))
                Button("Open in Terminal") { session.openStartCommandInTerminal() }
                    .buttonStyle(.link)
            }
            Toggle(isOn: $commitToGit) {
                Text("Commit the spec to Git")
                Text("Creates one commit in \(spec.folder.deletingLastPathComponent().lastPathComponent) so the spec has history.")
            }
            if let error {
                Text(error).foregroundStyle(.red)
            }
            HStack {
                Text(spec.folder.path(percentEncoded: false))
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer()
                Button("Show in Finder") { session.showInFinder() }
                Button("Done", action: done)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 540)
        .task(id: copied) {
            guard copied else { return }
            try? await Task.sleep(for: .seconds(2))
            copied = false
        }
        .task {
            for kind in DocKind.allCases {
                summaries[kind] = await parseDocument(session.documents[kind] ?? "", kind: kind).1
            }
        }
    }

    private func done() {
        do {
            try session.finish(commitToGit: commitToGit)
            dismiss()
        } catch {
            self.error = error.localizedDescription
        }
    }
}

#Preview {
    SpecReadySheet(session: PreviewData.session(PreviewData.done))
        .environment(PreviewData.appState([PreviewData.done]))
}
