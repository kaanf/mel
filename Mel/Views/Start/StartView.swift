import SwiftUI
import MelSpec

/// V2-0 Start (design/v2 V2-0-Start, and V2-0b with no agent): the agent as one status line, a repo
/// Mel found or a dropped folder or an idea, Start. Codex is hidden (OQ #28). With GitHub (GH-1, 1b,
/// 1c): the account under the agent, and the user's repos on a second tab; one not on this Mac is cloned.
struct StartView: View {
    @Environment(AppState.self) private var state
    @Environment(\.openSettings) private var openSettings
    @AppStorage("settingsTab") private var settingsTab = SettingsView.Pane.agents
    /// The row the user picked; until then the first repo, or the idea when Mel found none.
    @State private var picked: URL?
    @State private var isIdea = false
    @State private var dropped: [URL] = []
    @State private var error: String?
    /// GH-1: the On GitHub tab, and the repo picked there.
    @State private var onGitHub = false
    @State private var pickedRepo: GitHubRepo?
    @State private var isCloning = false
    @Environment(\.openURL) private var openURL
    /// Start was pressed: with the project added, or from an idea.
    let onStart: (_ fromIdea: Bool) -> Void

    static let installCommand = "npm install -g @anthropic-ai/claude-code"
    static let gitHubInstallCommand = "brew install gh"
    /// The repos listed: the most recently edited ones. Any other folder can be dropped on the window.
    private static let listed = 5

    private var folders: [FoundRepository] {
        let found = state.foundRepositories.sorted { ($0.modified ?? .distantPast) > ($1.modified ?? .distantPast) }.prefix(Self.listed)
        return dropped.map { FoundRepository(url: $0) } + found.filter { !dropped.contains($0.url) }
    }

    private var selected: URL? { isIdea ? nil : picked ?? folders.first?.url }

    private var showsGitHub: Bool { onGitHub && state.github.login != nil }
    private var repos: [GitHubRepo] { Array(state.githubRepos.prefix(Self.listed)) }
    private var selectedRepo: GitHubRepo? { isIdea ? nil : pickedRepo ?? repos.first }
    /// A repo already in ~/Developer under its name starts there instead of cloning.
    private func localFolder(_ repo: GitHubRepo) -> URL? {
        state.foundRepositories.first { $0.url.lastPathComponent == repo.name }?.url
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Space.x24) {
                header
                if state.agent == .missing {
                    missing
                    accounts(agent: false)
                } else {
                    accounts(agent: true)
                }
                projects
                HStack(spacing: Theme.Space.x12) {
                    Text(footNote)
                        .textStyle(Theme.Text.calloutLoose)
                        .foregroundStyle(Theme.Colors.secondaryLabel)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Button(startLabel, action: start)
                        .buttonStyle(AccentPillStyle(hint: "↩"))
                        .keyboardShortcut(.defaultAction)
                        .disabled(!state.agent.isReady || isCloning)
                }
            }
            .foregroundStyle(Theme.Colors.label)
            .frame(maxWidth: Theme.Size.startWidth - 2 * Theme.Space.x40)
            .padding(EdgeInsets(top: Theme.Size.startBar + Theme.Space.x8, leading: Theme.Space.x40, bottom: Theme.Space.x32, trailing: Theme.Space.x40))
            .frame(maxWidth: .infinity)
        }
        .defaultScrollAnchor(.center)
        .scrollBounceBehavior(.basedOnSize)
        .background(Theme.Colors.background)
        .ignoresSafeArea(.container, edges: .top)
        .toolbar(removing: .title)
        .dropDestination(for: URL.self) { urls, _ in
            let folders = urls.filter(\.hasDirectoryPath)
            guard let first = folders.first else { return false }
            dropped = folders + dropped.filter { !folders.contains($0) }
            picked = first
            isIdea = false
            return true
        }
        .alert("Couldn’t Add the Folder", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
        } message: {
            Text(error ?? "")
        }
        .task {
            if state.foundRepositories.isEmpty { await state.findRepositories() }
        }
        .task {
            if state.github == .checking { await state.scanGitHub() }
            if state.github.login != nil, pickedRepo == nil { onGitHub = !state.githubRepos.isEmpty && state.foundRepositories.isEmpty }
        }
        .animation(.board, value: state.github)
        .animation(.board, value: showsGitHub)
    }

    private var header: some View {
        VStack(spacing: Theme.Space.x10) {
            Image(.logo)
                .resizable()
                .interpolation(.high)
                .frame(width: Theme.Size.startLogo, height: Theme.Size.startLogo)
                .accessibilityHidden(true)
            Text("Welcome to Mel").textStyle(Theme.Text.title2).accessibilityAddTraits(.isHeader)
            Text("Describe what you want. Mel asks a few questions and writes a plan your coding agent can build, step by step.")
                .textStyle(Theme.Text.intro)
                .foregroundStyle(Theme.Colors.bodyLabel)
                .multilineTextAlignment(.center)
                .frame(maxWidth: Theme.Size.startTextWidth)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: Agent

    /// "Your agents" and GitHub: status lines, not steps. Without an agent, only GitHub's (V2-0b shows the agent above).
    private func accounts(agent: Bool) -> some View {
        VStack(alignment: .leading, spacing: Theme.Space.x6) {
            if agent { agents }
            gitHubLine
            switch state.github {
            case .signingIn(let code): signingIn(code).transition(.drop)
            case .missing: gitHubMissing.transition(.drop)
            default: EmptyView()
            }
        }
        .padding(.vertical, Theme.Space.x10)
        .padding(.horizontal, Theme.Space.x14)
        .background(Theme.Colors.fill, in: RoundedRectangle(cornerRadius: Theme.Radius.card))
    }

    private var agents: some View {
        HStack(spacing: Theme.Space.x10) {
            Text("Your agents").textStyle(Theme.Text.calloutBold).foregroundStyle(Theme.Colors.bodyLabel)
                .frame(width: Theme.Size.startLineLabel, alignment: .leading)
            HStack(spacing: Theme.Space.x6) {
                agentDot.frame(width: Theme.Size.topicDot, height: Theme.Size.topicDot)
                Text("Claude Code").textStyle(Theme.Text.callout)
            }
            .padding(.horizontal, Theme.Space.x10)
            .frame(height: Theme.Size.buttonMini)
            .surface(Theme.Colors.background, .fileChip, in: Capsule())
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Claude Code, \(state.agent.word)")
            Text(agentNote)
                .textStyle(Theme.Text.caption)
                .foregroundStyle(Theme.Colors.secondaryLabel)
                .frame(maxWidth: .infinity, alignment: .leading)
            if case .notSignedIn = state.agent {
                Button("Sign In", action: state.signIn).buttonStyle(DesignLinkStyle())
            } else {
                Button("Change", action: showAgents).buttonStyle(DesignLinkStyle())
            }
        }
    }

    // MARK: GitHub (GH-1)

    private var gitHubLine: some View {
        HStack(spacing: Theme.Space.x10) {
            Text("GitHub").textStyle(Theme.Text.calloutBold).foregroundStyle(Theme.Colors.bodyLabel)
                .frame(width: Theme.Size.startLineLabel, alignment: .leading)
            if let login = state.github.login {
                HStack(spacing: Theme.Space.x6) {
                    Circle().fill(Theme.Colors.success).frame(width: Theme.Size.topicDot, height: Theme.Size.topicDot)
                    Text(login).textStyle(Theme.Text.callout)
                }
                .padding(.horizontal, Theme.Space.x10)
                .frame(height: Theme.Size.buttonMini)
                .surface(Theme.Colors.background, .fileChip, in: Capsule())
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("GitHub, signed in as \(login)")
            }
            Text(gitHubNote)
                .textStyle(Theme.Text.caption)
                .foregroundStyle(Theme.Colors.secondaryLabel)
                .frame(maxWidth: .infinity, alignment: .leading)
            if state.github == .signedOut {
                Button("Sign in to GitHub…", action: state.signInToGitHub)
                    .buttonStyle(BoardPillStyle(kind: .quiet, height: Theme.Size.buttonMini, padding: Theme.Space.x10, text: Theme.Text.caption))
            }
        }
    }

    private var gitHubNote: String {
        switch state.github {
        case .checking: "Looking for the GitHub CLI…"
        case .signedIn: "Mel pushes each task and opens a pull request when a spec is built."
        default: "Optional. Without it Mel builds on this Mac and merges into main here."
        }
    }

    /// GH-1b: the code from `gh auth login --web`; GitHub opened in the browser.
    private func signingIn(_ code: String?) -> some View {
        HStack(spacing: Theme.Space.x12) {
            VStack(alignment: .leading, spacing: Theme.Space.x2) {
                Text(code == nil ? "Asking GitHub for a code…" : "Enter this code on GitHub").textStyle(Theme.Text.calloutBold)
                Text("GitHub opened in your browser. Mel goes on by itself once you approve.")
                    .textStyle(Theme.Text.caption)
                    .foregroundStyle(Theme.Colors.secondaryLabel)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if let code {
                Text(code).textStyle(Theme.Text.deviceCode).textSelection(.enabled)
                Button("Copy") { state.copy(code) }
                    .buttonStyle(BoardPillStyle(kind: .quiet, height: Theme.Size.buttonMini, padding: Theme.Space.x10, text: Theme.Text.caption))
                    .accessibilityLabel("Copy code")
            } else {
                ProgressView().controlSize(.small)
            }
            Button("Cancel", action: state.cancelGitHubSignIn).buttonStyle(DesignLinkStyle(text: Theme.Text.caption))
        }
        .padding(.vertical, Theme.Space.x10)
        .padding(.horizontal, Theme.Space.x12)
        .surface(Theme.Colors.background, .fileChip, in: RoundedRectangle(cornerRadius: Theme.Radius.row))
    }

    /// GH-1c: no GitHub CLI on this Mac.
    private var gitHubMissing: some View {
        VStack(alignment: .leading, spacing: Theme.Space.x8) {
            Text("To use GitHub, install the GitHub CLI in Terminal. Mel looks again when you come back to this window.")
                .textStyle(Theme.Text.callout)
                .foregroundStyle(Theme.Colors.bodyLabel)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: Theme.Space.x8) {
                Text(Self.gitHubInstallCommand)
                    .textStyle(Theme.Text.codeCaptionLoose)
                    .foregroundStyle(Theme.Colors.bodyLabel)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Button("Copy") { state.copy(Self.gitHubInstallCommand) }
                    .buttonStyle(BoardPillStyle(kind: .quiet, height: Theme.Size.buttonMini, padding: Theme.Space.x10, text: Theme.Text.caption))
                    .accessibilityLabel("Copy install command")
            }
            .padding(EdgeInsets(top: Theme.Space.x6, leading: Theme.Space.x10, bottom: Theme.Space.x6, trailing: Theme.Space.x6))
            .background(Theme.Colors.fill, in: RoundedRectangle(cornerRadius: Theme.Radius.row))
            HStack(spacing: Theme.Space.x12) {
                Button("Check Again") { Task { await state.scanGitHub() } }
                    .buttonStyle(BoardPillStyle(height: Theme.Size.buttonMini, padding: Theme.Space.x10, text: Theme.Text.callout))
                Button("No Homebrew? Other ways to install") { openURL(URL(string: "https://cli.github.com")!) }
                    .buttonStyle(DesignLinkStyle())
            }
        }
        .padding(.vertical, Theme.Space.x10)
        .padding(.horizontal, Theme.Space.x12)
        .surface(Theme.Colors.background, .fileChip, in: RoundedRectangle(cornerRadius: Theme.Radius.row))
    }

    @ViewBuilder
    private var agentDot: some View {
        switch state.agent {
        case .ready: Circle().fill(Theme.Colors.success)
        case .checking: Circle().strokeBorder(Theme.Colors.tertiary, lineWidth: Theme.Size.statusDotStroke)
        default: Circle().fill(Theme.Colors.caution)
        }
    }

    private var agentNote: String {
        switch state.agent {
        case .ready: "Mel uses it with your own account."
        case .checking: "Looking for it on this Mac…"
        case .notSignedIn: "Sign in once in Terminal."
        default: "It’s installed but doesn’t run."
        }
    }

    /// V2-0b: no agent on this Mac.
    private var missing: some View {
        VStack(alignment: .leading, spacing: Theme.Space.x10) {
            Text("Mel needs a coding agent on this Mac").textStyle(Theme.Text.bodyBold).foregroundStyle(Theme.Colors.bannerTitle)
            Text("Mel doesn’t run its own AI. Install one in Terminal and sign in once. Mel looks again when you come back to this window.")
                .textStyle(Theme.Text.calloutLoose)
                .foregroundStyle(Theme.Colors.bodyLabel)
            HStack(spacing: Theme.Space.x8) {
                Text("Claude Code").textStyle(Theme.Text.calloutBold).frame(width: Theme.Size.installName, alignment: .leading)
                Text(Self.installCommand)
                    .textStyle(Theme.Text.codeCaptionLoose)
                    .foregroundStyle(Theme.Colors.bodyLabel)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Button("Copy") { state.copy(Self.installCommand) }
                    .buttonStyle(BoardPillStyle(kind: .quiet, height: Theme.Size.buttonMini, padding: Theme.Space.x10, text: Theme.Text.caption))
                    .accessibilityLabel("Copy install command")
            }
            .padding(EdgeInsets(top: Theme.Space.x6, leading: Theme.Space.x10, bottom: Theme.Space.x6, trailing: Theme.Space.x6))
            .surface(Theme.Colors.background, .fileChip, in: RoundedRectangle(cornerRadius: Theme.Radius.row))
            HStack(spacing: Theme.Space.x12) {
                Button("Check Again") { Task { await state.scanForAgent() } }.buttonStyle(BoardPillStyle())
                Button("Installed somewhere else? Choose path…", action: showAgents).buttonStyle(DesignLinkStyle())
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Theme.Space.x14)
        .surface(Theme.Colors.bannerFill, .banner, in: RoundedRectangle(cornerRadius: Theme.Radius.card))
    }

    private func showAgents() {
        settingsTab = .agents
        openSettings()
    }

    // MARK: Project

    private var projects: some View {
        VStack(alignment: .leading, spacing: Theme.Space.x8) {
            HStack(spacing: Theme.Space.x12) {
                Text("What will you work on?").textStyle(Theme.Text.bodyBold).accessibilityAddTraits(.isHeader)
                    .frame(maxWidth: .infinity, alignment: .leading)
                HStack(spacing: Theme.Space.x2) {
                    ForEach([false, true], id: \.self) { github in
                        let isOn = showsGitHub == github
                        Button(github ? "On GitHub" : "On this Mac") { withAnimation(.board) { onGitHub = github } }
                            .buttonStyle(BoardSegmentStyle(isSelected: isOn, padding: Theme.Space.x10, text: isOn ? Theme.Text.calloutBold : Theme.Text.callout))
                            .disabled(github && state.github.login == nil)
                            .accessibilityAddTraits(isOn ? .isSelected : [])
                    }
                }
                .padding(Theme.Space.x2)
                .background(Theme.Colors.badgeFill, in: Capsule())
            }
            VStack(spacing: Theme.Space.x6) {
                if showsGitHub {
                    ForEach(repos) { repo in
                        row(name: repo.nameWithOwner, meta: Self.meta(repo), tag: localFolder(repo) == nil ? "Not on this Mac" : "On this Mac", isOn: selectedRepo == repo) {
                            pickedRepo = repo
                            isIdea = false
                        }
                    }
                } else {
                    ForEach(folders) { folder in
                        row(name: folder.url.lastPathComponent, meta: Self.meta(folder), isOn: selected == folder.url) {
                            picked = folder.url
                            isIdea = false
                        }
                    }
                }
                row(name: "No code yet, start from an idea", meta: state.github.login == nil ? "Mel makes a new folder for it" : "Mel makes a new folder and, if you want, a GitHub repo for it", isOn: isIdea || (showsGitHub ? repos.isEmpty : folders.isEmpty)) { isIdea = true }
            }
            HStack(spacing: Theme.Space.x8) {
                Text(showsGitHub ? "Your repos, newest first." : "Or drop a project folder anywhere on this window.")
                    .textStyle(Theme.Text.callout)
                    .foregroundStyle(Theme.Colors.secondaryLabel)
                if showsGitHub { RefreshReposButton() }
            }
        }
    }

    private func row(name: String, meta: String, tag: String? = nil, isOn: Bool, pick: @escaping () -> Void) -> some View {
        Button(action: pick) {
            HStack(spacing: Theme.Space.x12) {
                Circle()
                    .strokeBorder(isOn ? Theme.Colors.accent : .clear, lineWidth: Theme.Size.startRadioRing)
                    .surface(Theme.Colors.background, isOn ? .init() : .startRadioOff, in: Circle())
                    .frame(width: Theme.Size.startRadio, height: Theme.Size.startRadio)
                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: Theme.Space.x6) {
                        Text(name).textStyle(Theme.Text.bodyMedium).lineLimit(1)
                        if let tag {
                            Text(tag)
                                .textStyle(Theme.Text.repoTag)
                                .foregroundStyle(Theme.Colors.bodyLabel)
                                .padding(.horizontal, Theme.Space.x6)
                                .frame(height: Theme.Size.repoTag)
                                .background(Theme.Colors.badgeFill, in: Capsule())
                        }
                    }
                    Text(meta).textStyle(Theme.Text.caption).foregroundStyle(Theme.Colors.secondaryLabel).lineLimit(1).truncationMode(.middle)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.vertical, Theme.Space.x8)
            .padding(.horizontal, Theme.Space.x12)
            .frame(minHeight: Theme.Size.startRow)
            .surface(isOn ? Theme.Colors.accentTint : Theme.Colors.background, isOn ? .selected : .outlineCard, in: RoundedRectangle(cornerRadius: Theme.Radius.box))
            .contentShape(RoundedRectangle(cornerRadius: Theme.Radius.box))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }

    /// "~/Developer · Kotlin · edited today".
    static func meta(_ folder: FoundRepository, now: Date = .now) -> String {
        let age = folder.modified.map { date in
            Calendar.current.isDate(date, inSameDayAs: now) ? "edited today" : "edited " + RelativeDateTimeFormatter().localizedString(for: date, relativeTo: now)
        }
        let parent = folder.url.deletingLastPathComponent().path(percentEncoded: false)
        let place = parent.count > 1 && parent.hasSuffix("/") ? String(parent.dropLast()) : parent
        return ([place.abbreviatingHome, folder.language, age] as [String?]).compactMap(\.self).joined(separator: " · ")
    }

    /// "Private · Kotlin · updated 3 days ago".
    static func meta(_ repo: GitHubRepo, now: Date = .now) -> String {
        let age = repo.updatedAt.map { date in
            Calendar.current.isDate(date, inSameDayAs: now) ? "updated today" : "updated " + RelativeDateTimeFormatter().localizedString(for: date, relativeTo: now)
        }
        return ([repo.isPrivate ? "Private" : "Public", repo.isEmpty ? "empty" : repo.language, age] as [String?]).compactMap(\.self).joined(separator: " · ")
    }

    private var startLabel: String {
        if isCloning { return "Cloning…" }
        if showsGitHub, let repo = selectedRepo, localFolder(repo) == nil { return "Clone and Start" }
        return "Start"
    }

    private var footNote: String {
        if !state.agent.isReady { return state.agent == .missing ? "Start works once an agent is found." : "Start works once Claude Code is ready." }
        if showsGitHub, let repo = selectedRepo {
            return localFolder(repo) == nil
                ? "Mel clones it into ~/Developer/\(repo.name), then reads it in the background."
                : "It’s in ~/Developer/\(repo.name). Mel reads it once in the background, about a minute."
        }
        if isIdea, state.github.login != nil { return "Next you name it and choose where its code lives." }
        return selected == nil
            ? "Mel learns your project from your first spec."
            : "Mel reads the project once in the background, about a minute. You can start writing right away."
    }

    private func start() {
        if showsGitHub {
            guard let repo = selectedRepo else { return open(nil) }
            if let folder = localFolder(repo) { return open(folder) }
            isCloning = true
            Task {
                defer { isCloning = false }
                do {
                    try await state.cloneProject(repo)
                    onStart(false)
                } catch {
                    self.error = error.localizedDescription
                }
            }
            return
        }
        open(selected)
    }

    private func open(_ folder: URL?) {
        do {
            if let folder { try state.startProject(folder) }
            onStart(folder == nil)
        } catch {
            self.error = error.localizedDescription
        }
    }
}

#Preview("Repos found") {
    StartView { _ in }
        .environment(PreviewData.appState([], projects: [], foundRepositories: PreviewData.repositories))
        .frame(width: Theme.Size.windowWidth, height: Theme.Size.windowHeight)
}

#Preview("GitHub, signed in") {
    StartView { _ in }
        .environment(PreviewData.appState([], projects: [], foundRepositories: PreviewData.repositories, github: .signedIn("kaanf"), githubRepos: PreviewData.githubRepos))
        .frame(width: Theme.Size.windowWidth, height: Theme.Size.windowHeight)
}

#Preview("GitHub, signing in") {
    StartView { _ in }
        .environment(PreviewData.appState([], projects: [], foundRepositories: PreviewData.repositories, github: .signingIn(code: "5C2F-81AD")))
        .frame(width: Theme.Size.windowWidth, height: Theme.Size.windowHeight)
}

#Preview("No GitHub CLI") {
    StartView { _ in }
        .environment(PreviewData.appState([], projects: [], foundRepositories: PreviewData.repositories, github: .missing))
        .frame(width: Theme.Size.windowWidth, height: Theme.Size.windowHeight)
}

#Preview("No agent") {
    StartView { _ in }
        .environment(PreviewData.appState([], agent: .missing, projects: [], foundRepositories: PreviewData.repositories))
        .frame(width: Theme.Size.windowWidth, height: Theme.Size.windowHeight)
}

#Preview("Not signed in") {
    StartView { _ in }
        .environment(PreviewData.appState([], agent: PreviewData.notSignedIn, projects: [], foundRepositories: PreviewData.repositories))
        .frame(width: Theme.Size.windowWidth, height: Theme.Size.windowHeight)
}

#Preview("No repos, idea") {
    StartView { _ in }
        .environment(PreviewData.appState([], projects: []))
        .frame(width: Theme.Size.windowWidth, height: Theme.Size.windowHeight)
}
