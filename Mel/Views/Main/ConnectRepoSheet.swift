import SwiftUI
import MelSpec

/// GH-3 (design/v2 GH-3-Project-Connect): a project only on this Mac gets a GitHub repo, from the
/// project menu's Connect to GitHub…. A new repo, or an empty one the user made; one with its own
/// history is refused.
struct ConnectRepoSheet: View {
    @Environment(AppState.self) private var state
    @Environment(\.dismiss) private var dismiss
    let project: Project
    @State private var choice: RepoChoice
    @State private var isWorking = false
    @State private var error: String?

    init(project: Project) {
        self.project = project
        _choice = State(initialValue: RepoChoice(place: .newRepo, name: RepoChoice.repoName(project.name)))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.x16) {
            VStack(alignment: .leading, spacing: Theme.Space.x6) {
                Text("Connect \(project.name) to GitHub").textStyle(Theme.Text.headline).accessibilityAddTraits(.isHeader)
                Text("This project is only on this Mac. With a GitHub repo, Mel pushes each task and opens a pull request when a spec is built.")
                    .textStyle(Theme.Text.calloutLoose)
                    .foregroundStyle(Theme.Colors.secondaryLabel)
                    .fixedSize(horizontal: false, vertical: true)
            }
            RepoChoiceView(choice: $choice, connecting: true)
            if let error {
                Text(error).textStyle(Theme.Text.captionLoose).foregroundStyle(Theme.Colors.cautionText).fixedSize(horizontal: false, vertical: true)
            }
            HStack(spacing: Theme.Space.x12) {
                if let login = state.github.login {
                    Text("Through your GitHub CLI, as \(login).").textStyle(Theme.Text.caption).foregroundStyle(Theme.Colors.secondaryLabel)
                }
                Spacer(minLength: 0)
                if isWorking { ProgressView().controlSize(.small) }
                Button("Cancel") { dismiss() }
                    .buttonStyle(DesignLinkStyle())
                    .keyboardShortcut(.cancelAction)
                Button(choice.confirm(connecting: true), action: connect)
                    .buttonStyle(AccentPillStyle(padding: Theme.Space.x16, hint: "↩"))
                    .keyboardShortcut(.defaultAction)
                    .disabled(state.github.login == nil || !choice.isReady(connecting: true) || isWorking)
            }
        }
        .foregroundStyle(Theme.Colors.label)
        .padding(Theme.Space.x24)
        .frame(width: Theme.Size.repoSheet)
        .background(Theme.Colors.background)
        .animation(.board, value: choice)
    }

    private func connect() {
        isWorking = true
        error = nil
        Task {
            defer { isWorking = false }
            do {
                switch choice.place {
                case .newRepo: try await state.createRepo(for: project, name: choice.name.trimmingCharacters(in: .whitespaces), isPrivate: choice.isPrivate)
                case .existing: if let repo = choice.repo { try await state.connectRepo(repo, to: project) }
                case .mac: break
                }
                dismiss()
            } catch {
                self.error = error.localizedDescription
            }
        }
    }
}

#Preview("New repo") {
    ConnectRepoSheet(project: PreviewData.project)
        .environment(PreviewData.appState([], github: .signedIn("kaanf"), githubRepos: PreviewData.githubRepos))
}

#Preview("Signed out") {
    ConnectRepoSheet(project: PreviewData.project)
        .environment(PreviewData.appState([], github: .signedOut))
}
