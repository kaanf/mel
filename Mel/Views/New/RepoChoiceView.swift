import SwiftUI
import MelSpec

/// Where a product's code lives (GH-2), or where a project on this Mac goes on GitHub (GH-3).
struct RepoChoice: Hashable {
    enum Place: Hashable { case newRepo, existing, mac }
    var place: Place
    /// The new repo's name, from the product's name.
    var name = ""
    var isPrivate = true
    var repo: GitHubRepo?
}

/// GH-2 / GH-3: A new GitHub repo, A repo you already made, Only on this Mac (not when connecting).
struct RepoChoiceView: View {
    @Environment(AppState.self) private var state
    @Binding var choice: RepoChoice
    /// GH-3: a project already on this Mac; its repo must be empty.
    var connecting = false

    private var login: String? { state.github.login }
    /// Empty repos first: those are the ones made for a new product.
    private var repos: [GitHubRepo] { state.githubRepos.filter(\.isEmpty) + state.githubRepos.filter { !$0.isEmpty } }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.x8) {
            Text("Where will its code live?").textStyle(Theme.Text.calloutBold).accessibilityAddTraits(.isHeader)
            VStack(spacing: Theme.Space.x6) {
                option(.newRepo, "A new GitHub repo", connecting ? "Mel creates it, adds it as origin and pushes what’s committed." : "Mel creates it and pushes the first commit.") { newRepo }
                option(.existing, "A repo you already made", connecting ? "Mel adds it as origin and pushes what’s committed." : "Mel clones it into ~/Developer and starts there.") { existing }
                if !connecting {
                    option(.mac, "Only on this Mac", "Connect it later from the project menu. Building merges into main here.") { EmptyView() }
                }
            }
            if login == nil { signIn }
        }
        .animation(.board, value: choice.place)
        .task { if state.github == .checking { await state.scanGitHub() } }
    }

    private func option(_ place: RepoChoice.Place, _ name: String, _ meta: String, @ViewBuilder detail: () -> some View) -> some View {
        let isOn = choice.place == place
        let isOff = place != .mac && login == nil
        return VStack(alignment: .leading, spacing: Theme.Space.x8) {
            Button { choice.place = place } label: {
                HStack(spacing: Theme.Space.x12) {
                    Circle()
                        .strokeBorder(isOn ? Theme.Colors.accent : .clear, lineWidth: Theme.Size.startRadioRing)
                        .surface(Theme.Colors.background, isOn ? .init() : .startRadioOff, in: Circle())
                        .frame(width: Theme.Size.startRadio, height: Theme.Size.startRadio)
                    VStack(alignment: .leading, spacing: 0) {
                        Text(name).textStyle(Theme.Text.bodyMedium)
                        Text(meta).textStyle(Theme.Text.caption).foregroundStyle(Theme.Colors.secondaryLabel).fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(isOff)
            .accessibilityAddTraits(isOn ? .isSelected : [])
            if isOn { detail().padding(.leading, Theme.Size.startRadio + Theme.Space.x12).transition(.drop) }
        }
        .opacity(isOff ? 0.5 : 1)
        .padding(.vertical, Theme.Space.x10)
        .padding(.horizontal, Theme.Space.x12)
        .surface(isOn ? Theme.Colors.accentTint : Theme.Colors.background, isOn ? .selected : .outlineCard, in: RoundedRectangle(cornerRadius: Theme.Radius.box))
    }

    private var newRepo: some View {
        VStack(alignment: .leading, spacing: Theme.Space.x8) {
            HStack(spacing: Theme.Space.x6) {
                Text(login ?? "").textStyle(Theme.Text.callout).foregroundStyle(Theme.Colors.bodyLabel)
                Text("/").textStyle(Theme.Text.body).foregroundStyle(Theme.Colors.secondaryLabel)
                TextField("repo-name", text: $choice.name)
                    .textFieldStyle(.plain)
                    .textStyle(Theme.Text.codeCaption)
                    .padding(.horizontal, Theme.Space.x8)
                    .frame(height: Theme.Size.buttonMini + 2)
                    .surface(Theme.Colors.background, .focus, in: RoundedRectangle(cornerRadius: Theme.Radius.row))
                    .accessibilityLabel("Repo name")
            }
            HStack(spacing: Theme.Space.x10) {
                HStack(spacing: Theme.Space.x2) {
                    ForEach([true, false], id: \.self) { isPrivate in
                        let isOn = choice.isPrivate == isPrivate
                        Button(isPrivate ? "Private" : "Public") { choice.isPrivate = isPrivate }
                            .buttonStyle(BoardSegmentStyle(isSelected: isOn, height: Theme.Size.chip - 4, padding: Theme.Space.x10, text: isOn ? Theme.Text.captionBold : Theme.Text.caption))
                            .accessibilityAddTraits(isOn ? .isSelected : [])
                    }
                }
                .padding(Theme.Space.x2)
                .background(Theme.Colors.badgeFill, in: Capsule())
                Text(choice.isPrivate ? "Only you and people you add can see it." : "Anyone can see it. Your spec files go there too.")
                    .textStyle(Theme.Text.caption)
                    .foregroundStyle(Theme.Colors.secondaryLabel)
            }
        }
    }

    private var existing: some View {
        VStack(alignment: .leading, spacing: Theme.Space.x6) {
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(repos) { repo in
                        let isOn = choice.repo == repo
                        Button { choice.repo = repo } label: {
                            HStack(spacing: Theme.Space.x8) {
                                Text(repo.nameWithOwner).textStyle(Theme.Text.codeCaption).lineLimit(1).frame(maxWidth: .infinity, alignment: .leading)
                                Text(repo.isEmpty ? "Empty" : StartView.meta(repo)).textStyle(Theme.Text.caption).foregroundStyle(isOn ? Theme.Colors.bodyLabel : Theme.Colors.secondaryLabel)
                            }
                            .padding(.horizontal, Theme.Space.x10)
                            .frame(height: Theme.Size.repoListRow)
                            .background(isOn ? Theme.Colors.accentSelectedFill : .clear)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(isOn ? .isSelected : [])
                        Divider()
                    }
                }
            }
            .frame(maxHeight: Theme.Size.repoListRow * 4)
            .surface(Theme.Colors.background, .outlineCard, in: RoundedRectangle(cornerRadius: Theme.Radius.row))
            if let repo = choice.repo, !repo.isEmpty {
                Text(connecting ? "This repo has its own history. Mel won’t mix two histories: pick an empty repo or make a new one."
                                : "This repo has code already. Mel clones it and reads it like any project.")
                    .textStyle(Theme.Text.captionLoose)
                    .foregroundStyle(Theme.Colors.cautionText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    @ViewBuilder
    private var signIn: some View {
        HStack(spacing: Theme.Space.x8) {
            switch state.github {
            case .signingIn(let code?):
                Text("Enter \(code) on GitHub in your browser.").textStyle(Theme.Text.caption).foregroundStyle(Theme.Colors.secondaryLabel)
                Button("Copy") { state.copy(code) }.buttonStyle(DesignLinkStyle(text: Theme.Text.caption))
            case .missing:
                Text("To use GitHub, install the GitHub CLI: \(StartView.gitHubInstallCommand)").textStyle(Theme.Text.caption).foregroundStyle(Theme.Colors.secondaryLabel)
            case .signedOut:
                Text("Sign in to GitHub to put the code there.").textStyle(Theme.Text.caption).foregroundStyle(Theme.Colors.secondaryLabel)
                Button("Sign in to GitHub…", action: state.signInToGitHub).buttonStyle(DesignLinkStyle(text: Theme.Text.caption))
            default:
                ProgressView().controlSize(.mini)
            }
        }
    }
}

extension RepoChoice {
    /// What the sheet's main button says.
    func confirm(connecting: Bool) -> String {
        switch place {
        case .newRepo: connecting ? "Create Repo and Push" : "Create Repo and Start"
        case .existing: connecting ? "Connect and Push" : "Clone and Start"
        case .mac: "Start"
        }
    }

    /// The button stays off until the choice can be carried out.
    func isReady(connecting: Bool) -> Bool {
        switch place {
        case .newRepo: !name.trimmingCharacters(in: .whitespaces).isEmpty
        case .existing: repo.map { !connecting || $0.isEmpty } ?? false
        case .mac: true
        }
    }

    /// A repo name from a product name: "Yoga Studio Booking" → "yoga-studio-booking".
    static func repoName(_ name: String) -> String {
        name.lowercased().split { !$0.isLetter && !$0.isNumber }.joined(separator: "-")
    }
}

#Preview("A new repo") {
    @Previewable @State var choice = RepoChoice(place: .newRepo, name: "yoga-studio-booking")
    RepoChoiceView(choice: $choice)
        .environment(PreviewData.appState([], github: .signedIn("kaanf"), githubRepos: PreviewData.githubRepos))
        .padding(Theme.Space.x24)
        .frame(width: Theme.Size.repoSheet)
}

#Preview("A repo you made") {
    @Previewable @State var choice = RepoChoice(place: .existing, repo: PreviewData.githubRepos[2])
    RepoChoiceView(choice: $choice)
        .environment(PreviewData.appState([], github: .signedIn("kaanf"), githubRepos: PreviewData.githubRepos))
        .padding(Theme.Space.x24)
        .frame(width: Theme.Size.repoSheet)
}

#Preview("Connecting, repo with history") {
    @Previewable @State var choice = RepoChoice(place: .existing, repo: PreviewData.githubRepos[0])
    RepoChoiceView(choice: $choice, connecting: true)
        .environment(PreviewData.appState([], github: .signedIn("kaanf"), githubRepos: PreviewData.githubRepos))
        .padding(Theme.Space.x24)
        .frame(width: Theme.Size.repoSheet)
}

#Preview("Signed out") {
    @Previewable @State var choice = RepoChoice(place: .mac)
    RepoChoiceView(choice: $choice)
        .environment(PreviewData.appState([], github: .signedOut))
        .padding(Theme.Space.x24)
        .frame(width: Theme.Size.repoSheet)
}
