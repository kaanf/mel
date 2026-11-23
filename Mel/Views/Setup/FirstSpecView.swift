import SwiftUI
import MelSpec

/// A4x First spec, no project (design/v2 Native-E4-FirstSpec): B1's empty state for a new user.
/// Only Product works; Feature and Quick fix need a project (A2).
struct FirstSpecView: View {
    @Environment(AppState.self) private var state
    @State private var idea: String
    @State private var files: [URL] = []
    @State private var error: String?
    let onAddProject: () -> Void
    let onStart: () -> Void

    init(idea: String = "", onAddProject: @escaping () -> Void, onStart: @escaping () -> Void) {
        _idea = State(initialValue: idea)
        self.onAddProject = onAddProject
        self.onStart = onStart
    }

    private var trimmedIdea: String { idea.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var hasIdea: Bool { !trimmedIdea.isEmpty }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Space.x22) {
                VStack(alignment: .leading, spacing: Theme.Space.x8) {
                    Text("What are you making?")
                        .textStyle(Theme.Text.bodyBold)
                        .foregroundStyle(Theme.Colors.label)
                    HStack(spacing: Theme.Space.x8) {
                        sizeCard("Product", note: "A new app from an idea", isLocked: false)
                        sizeCard("Feature", note: "One feature in an existing app", isLocked: true)
                        sizeCard("Quick fix", note: "A bug or a small change", isLocked: true)
                    }
                    .fixedSize(horizontal: false, vertical: true)
                }
                VStack(alignment: .leading, spacing: Theme.Space.x2) {
                    Text("Untitled Spec")
                        .textStyle(Theme.Text.largeTitle)
                        .foregroundStyle(Theme.Colors.tertiary)
                    Text("Mel suggests a name once you describe your idea.")
                        .textStyle(Theme.Text.callout)
                        .foregroundStyle(Theme.Colors.secondaryLabel)
                }
                ideaBox
                examples
                footer
            }
            .frame(maxWidth: Theme.Size.newSpecWidth)
            .padding(EdgeInsets(top: Theme.Space.x12, leading: Theme.Space.x32, bottom: Theme.Space.x40, trailing: Theme.Space.x32))
            .frame(maxWidth: .infinity)
        }
        .scrollIndicators(.automatic)
        .setupChrome(title: "New Spec")
        .alert("Couldn’t Start", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
        } message: {
            Text(error ?? "")
        }
    }

    private func sizeCard(_ title: String, note: String, isLocked: Bool) -> some View {
        VStack(alignment: .leading, spacing: Theme.Space.x3) {
            Text(title)
                .textStyle(Theme.Text.bodyBold)
                .foregroundStyle(isLocked ? Theme.Colors.secondaryLabel : Theme.Colors.label)
            Text(note)
                .textStyle(Theme.Text.caption)
                .foregroundStyle(Theme.Colors.bodyLabel)
            if isLocked {
                Button("Needs a project · Add One", action: onAddProject)
                    .buttonStyle(DesignLinkStyle(text: Theme.Text.caption))
            }
        }
        .padding(EdgeInsets(top: Theme.Space.x10, leading: Theme.Space.x12, bottom: Theme.Space.x10, trailing: Theme.Space.x12))
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .surface(isLocked ? Theme.Colors.fillSubtle : Theme.Colors.accentSelectedFill, isLocked ? .outlineLight : .selected, in: RoundedRectangle(cornerRadius: Theme.Radius.card))
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isLocked ? [] : .isSelected)
    }

    private var ideaBox: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Your idea")
                .textStyle(Theme.Text.captionBold)
                .foregroundStyle(Theme.Colors.secondaryLabel)
                .padding(EdgeInsets(top: Theme.Space.x14, leading: Theme.Space.x16, bottom: 0, trailing: Theme.Space.x16))
            IdeaTextArea(text: $idea, label: "Your idea", placeholder: "What should it do, and who is it for? Plain words are fine. A messy paragraph is enough.")
            if !files.isEmpty {
                FlowLayout(spacing: Theme.Space.x6) {
                    ForEach(files, id: \.self) { url in
                        EvidenceChip(name: url.lastPathComponent, kind: NewSpecView.kind(of: url)) { files.removeAll { $0 == url } }
                    }
                }
                .padding(EdgeInsets(top: 0, leading: Theme.Space.x16, bottom: Theme.Space.x10, trailing: Theme.Space.x16))
            }
            Text("You can also drop screenshots, sketches or a doc you already wrote.")
                .textStyle(Theme.Text.caption)
                .foregroundStyle(Theme.Colors.secondaryLabel)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(EdgeInsets(top: Theme.Space.x8, leading: Theme.Space.x16, bottom: Theme.Space.x10, trailing: Theme.Space.x16))
                .overlay(alignment: .top) { Rectangle().fill(Theme.Colors.separatorFaint).frame(height: Theme.Size.hairline) }
        }
        .surface(Theme.Colors.fill, .outlineFaint, in: RoundedRectangle(cornerRadius: Theme.Radius.panel))
        .dropDestination(for: URL.self) { urls, _ in
            files += urls.filter { !files.contains($0) }
            return !urls.isEmpty
        }
    }

    private var examples: some View {
        VStack(alignment: .leading, spacing: Theme.Space.x8) {
            Text("Not sure how to start? Try one")
                .textStyle(Theme.Text.bodyBold)
                .foregroundStyle(Theme.Colors.label)
            FlowLayout(spacing: Theme.Space.x6) {
                ForEach(NewSpecView.examples, id: \.0) { label, text in
                    Button { idea = text } label: {
                        Text(label)
                            .textStyle(Theme.Text.callout)
                            .foregroundStyle(Theme.Colors.label)
                            .padding(.horizontal, Theme.Space.x12)
                            .frame(height: Theme.Size.button)
                            .background(Theme.Colors.chipFill, in: Capsule())
                            .contentShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var footer: some View {
        HStack(spacing: Theme.Space.x8) {
            Text(hasIdea ? "About 5 questions, then 5 files and a final check." : "Describe your idea to start. Nothing is written until you press Start.")
                .textStyle(Theme.Text.callout)
                .foregroundStyle(Theme.Colors.secondaryLabel)
                .frame(maxWidth: .infinity, alignment: .leading)
            Button("Start", action: start)
                .buttonStyle(DesignButtonStyle(leading: Theme.Space.x20, trailing: Theme.Space.x12, keyHint: "⌘↩", elevation: .init()))
                .keyboardShortcut(.return, modifiers: .command)
                .disabled(!hasIdea || !state.agent.isReady)
        }
        .padding(.top, Theme.Space.x4)
    }

    /// A Product without a project: core creates `~/Developer/<slug>/` as the project.
    private func start() {
        guard hasIdea, state.agent.isReady else { return }
        do {
            let session = try state.createSpec(name: "Untitled Spec", idea: trimmedIdea, size: .product, project: nil, files: files)
            onStart()
            Task { await session.start() }
        } catch {
            self.error = error.localizedDescription
        }
    }
}

#Preview("Empty") {
    FirstSpecView(onAddProject: {}, onStart: {})
        .environment(PreviewData.appState([], projects: []))
        .frame(width: Theme.Size.windowWidth, height: Theme.Size.windowHeight)
}

#Preview("With idea") {
    FirstSpecView(idea: NewSpecView.examples[1].1, onAddProject: {}, onStart: {})
        .environment(PreviewData.appState([], projects: []))
        .frame(width: Theme.Size.windowWidth, height: Theme.Size.windowHeight)
}
