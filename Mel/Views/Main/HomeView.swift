import SwiftUI
import MelSpec

/// C3 Home, no specs yet (design/v2 Native-E3-Home): how it works, three start cards, New Spec.
/// The cards open B1 with their size picked. Time estimates are hidden in v0.3 (V2 §2).
struct HomeView: View {
    @Environment(AppState.self) private var state
    let onNewSpec: (SpecSize?) -> Void

    private static let steps = [
        ("Describe", "An idea, a feature or a bug."),
        ("Answer", "A few questions. Skip any."),
        ("Review", "Plain Markdown files, one at a time."),
        ("Hand off", "Any coding agent builds from them."),
    ]

    private var project: Project? { state.projects.first { !$0.isMissing } }

    private var starts: [(size: SpecSize, title: String, text: String)] {
        [
            (.quickFix, "Fix a bug", "Paste a log or describe what breaks."),
            (.feature, "Add a feature", project.map { "Extend \($0.name)." } ?? "Extend an existing app."),
            (.product, "Plan a new app", "From an idea, with screens."),
        ]
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Space.x28) {
                VStack(alignment: .leading, spacing: Theme.Space.x8) {
                    Text("Write your first spec").textStyle(Theme.Text.title1).accessibilityAddTraits(.isHeader)
                    Text("Describe what you want in plain words. Mel’s agent asks a few questions, writes the spec files, and checks them against each other before any code is written.")
                        .textStyle(Theme.Text.intro)
                        .foregroundStyle(Theme.Colors.bodyLabel)
                        .frame(maxWidth: Theme.Size.homeTextWidth, alignment: .leading)
                }
                LazyVGrid(columns: [GridItem(.adaptive(minimum: Theme.Size.homeStepMin), spacing: Theme.Space.x10)], spacing: Theme.Space.x10) {
                    ForEach(Self.steps.indices, id: \.self) { i in
                        VStack(alignment: .leading, spacing: Theme.Space.x4) {
                            Text("\(i + 1)").textStyle(Theme.Text.codeCaption).foregroundStyle(Theme.Colors.secondaryLabel)
                            Text(Self.steps[i].0).textStyle(Theme.Text.bodyBold)
                            Text(Self.steps[i].1).textStyle(Theme.Text.callout).foregroundStyle(Theme.Colors.bodyLabel)
                        }
                        .padding(Theme.Space.x12)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                        .background(Theme.Colors.fill, in: RoundedRectangle(cornerRadius: Theme.Radius.card))
                        .accessibilityElement(children: .combine)
                    }
                }
                VStack(alignment: .leading, spacing: Theme.Space.x8) {
                    Text("Start with").textStyle(Theme.Text.bodyBold).padding(.horizontal, Theme.Space.x4).accessibilityAddTraits(.isHeader)
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: Theme.Size.homeStartMin), spacing: Theme.Space.x10)], spacing: Theme.Space.x10) {
                        ForEach(starts, id: \.size) { start in
                            Button { onNewSpec(start.size) } label: {
                                VStack(alignment: .leading, spacing: Theme.Space.x4) {
                                    Text(start.title).textStyle(Theme.Text.bodyBold)
                                    Text(start.text).textStyle(Theme.Text.callout).foregroundStyle(Theme.Colors.bodyLabel)
                                    Text(start.size.files.count == 1 ? "1 file" : "\(start.size.files.count) files")
                                        .textStyle(Theme.Text.caption)
                                        .foregroundStyle(Theme.Colors.secondaryLabel)
                                }
                                .padding(Theme.Space.x14)
                                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                                .surface(.clear, .outlineList, in: RoundedRectangle(cornerRadius: Theme.Radius.card))
                                .contentShape(RoundedRectangle(cornerRadius: Theme.Radius.card))
                            }
                            .buttonStyle(.plain)
                            .disabled(!state.agent.isReady || (start.size.needsProject && project == nil))
                        }
                    }
                }
                HStack(spacing: Theme.Space.x12) {
                    Button("New Spec") { onNewSpec(nil) }
                        .buttonStyle(DesignButtonStyle(leading: Theme.Space.x18, trailing: Theme.Space.x12, keyHint: "⌘N"))
                        .disabled(!state.agent.isReady)
                    Text("Writing with Claude Code on your account. Change in Settings.")
                        .textStyle(Theme.Text.callout)
                        .foregroundStyle(Theme.Colors.secondaryLabel)
                }
            }
            .foregroundStyle(Theme.Colors.label)
            .frame(maxWidth: Theme.Size.homeWidth)
            .padding(EdgeInsets(top: Theme.Space.x72, leading: Theme.Space.x32, bottom: Theme.Space.x40, trailing: Theme.Space.x32))
            .frame(maxWidth: .infinity)
        }
        .background(Theme.Colors.background)
        // Drawn without a toolbar row, like B7.
        .ignoresSafeArea(.container, edges: .top)
        .toolbar(removing: .title)
        .toolbarBackgroundVisibility(.hidden, for: .windowToolbar)
    }
}

#Preview("Home") {
    NavigationStack {
        HomeView { _ in }
    }
    .environment(PreviewData.appState([]))
    .frame(width: 1048, height: 800)
}
