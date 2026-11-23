import SwiftUI
import MelSpec
import UniformTypeIdentifiers

/// Name, idea and parent folder for a new spec.
struct NewSpecSheet: View {
    @Environment(AppState.self) private var state
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var idea = ""
    @State private var parent: URL?
    @State private var choosingFolder = false
    @State private var showHelp = false
    @State private var error: String?

    /// Parent folders of existing specs (…/<parent>/<slug>/specs), most recent first.
    private var recentFolders: [URL] {
        var seen = Set<URL>()
        return state.specs
            .map { $0.folder.deletingLastPathComponent().deletingLastPathComponent() }
            .filter { seen.insert($0).inserted }
    }

    private var folder: URL { parent ?? recentFolders.first ?? .homeDirectory }

    private var isValid: Bool {
        state.agent.isReady
            && !name.trimmingCharacters(in: .whitespaces).isEmpty
            && !idea.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("New Spec").font(.title2.bold())
                Text("Describe your idea. The agent asks a few questions, then drafts the spec with you.")
                    .foregroundStyle(.secondary)
            }
            Form {
                TextField("Name", text: $name, prompt: Text("Yoga Studio Booking"))
                LabeledContent("Idea") {
                    VStack(alignment: .leading, spacing: 4) {
                        TextField("Idea", text: $idea, prompt: Text("What should it do, and for whom?"), axis: .vertical)
                            .lineLimit(6, reservesSpace: true)
                            .labelsHidden()
                        Text("Plain words are fine. Say who uses it and what they do.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                LabeledContent("Agent") {
                    HStack {
                        Text("Claude Code")
                        Text(state.agent.isReady ? "Found on this Mac" : "Not ready")
                            .foregroundStyle(.secondary)
                    }
                }
                LabeledContent("Save in") {
                    VStack(alignment: .leading, spacing: 4) {
                        Menu(folder.lastPathComponent) {
                            ForEach(recentFolders, id: \.self) { url in
                                Button(url.lastPathComponent) { parent = url }
                            }
                            if !recentFolders.isEmpty { Divider() }
                            Button("Choose…") { choosingFolder = true }
                        }
                        .fixedSize()
                        Text(folder.path(percentEncoded: false))
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .formStyle(.columns)
            if let error {
                Text(error).foregroundStyle(.red)
            }
            HStack {
                HelpLink { showHelp = true }
                    .popover(isPresented: $showHelp) {
                        Text("Mel creates a folder for the spec inside the folder you choose. The agent asks questions until it understands the idea, then writes PRODUCT.md, REQUIREMENTS.md, DESIGN.md and TASKS.md one at a time for you to review.")
                            .frame(width: 280)
                            .padding()
                    }
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Continue", action: create)
                    .keyboardShortcut(.defaultAction)
                    .disabled(!isValid)
            }
        }
        .padding(20)
        .frame(width: 540)
        .fileImporter(isPresented: $choosingFolder, allowedContentTypes: [.folder]) { result in
            if case .success(let url) = result { parent = url }
        }
    }

    private func create() {
        do {
            let session = try state.createSpec(
                name: name.trimmingCharacters(in: .whitespaces),
                idea: idea.trimmingCharacters(in: .whitespacesAndNewlines),
                parentFolder: folder
            )
            state.selection = session.spec.id
            dismiss()
            Task { await session.start() }
        } catch {
            self.error = error.localizedDescription
        }
    }
}

#Preview("Empty") {
    NewSpecSheet().environment(PreviewData.appState([]))
}

#Preview("With recent folders") {
    NewSpecSheet().environment(PreviewData.appState([PreviewData.discovery]))
}

#Preview("No agent") {
    NewSpecSheet().environment(PreviewData.appState([], agent: .missing))
}
