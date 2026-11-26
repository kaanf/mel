import SwiftUI
import MelSpec

/// V2-0 Start (design/v2 V2-0-Start, and V2-0b with no agent): the agent as one status line, a repo
/// Mel found or a dropped folder or an idea, Start. Codex is hidden (OQ #28).
struct StartView: View {
    @Environment(AppState.self) private var state
    @Environment(\.openSettings) private var openSettings
    @AppStorage("settingsTab") private var settingsTab = SettingsView.Pane.agents
    /// The row the user picked; until then the first repo, or the idea when Mel found none.
    @State private var picked: URL?
    @State private var isIdea = false
    @State private var dropped: [URL] = []
    @State private var error: String?
    /// Start was pressed: with the project added, or from an idea.
    let onStart: (_ fromIdea: Bool) -> Void

    static let installCommand = "npm install -g @anthropic-ai/claude-code"
    /// The repos listed: the most recently edited ones. Any other folder can be dropped on the window.
    private static let listed = 5

    private var folders: [FoundRepository] {
        let found = state.foundRepositories.sorted { ($0.modified ?? .distantPast) > ($1.modified ?? .distantPast) }.prefix(Self.listed)
        return dropped.map { FoundRepository(url: $0) } + found.filter { !dropped.contains($0.url) }
    }

    private var selected: URL? { isIdea ? nil : picked ?? folders.first?.url }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Space.x24) {
                header
                if state.agent == .missing { missing } else { agents }
                projects
                HStack(spacing: Theme.Space.x12) {
                    Text(footNote)
                        .textStyle(Theme.Text.calloutLoose)
                        .foregroundStyle(Theme.Colors.secondaryLabel)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Button("Start", action: start)
                        .buttonStyle(AccentPillStyle(hint: "↩"))
                        .keyboardShortcut(.defaultAction)
                        .disabled(!state.agent.isReady)
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
        .toolbarBackgroundVisibility(.hidden, for: .windowToolbar)
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

    /// "Your agents": one status line, not a step.
    private var agents: some View {
        HStack(spacing: Theme.Space.x10) {
            Text("Your agents").textStyle(Theme.Text.calloutBold).foregroundStyle(Theme.Colors.bodyLabel)
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
        .padding(.vertical, Theme.Space.x10)
        .padding(.horizontal, Theme.Space.x14)
        .background(Theme.Colors.fill, in: RoundedRectangle(cornerRadius: Theme.Radius.card))
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
            Text("What will you work on?").textStyle(Theme.Text.bodyBold).accessibilityAddTraits(.isHeader)
            VStack(spacing: Theme.Space.x6) {
                ForEach(folders) { folder in
                    row(name: folder.url.lastPathComponent, meta: Self.meta(folder), isOn: selected == folder.url) {
                        picked = folder.url
                        isIdea = false
                    }
                }
                row(name: "No code yet, start from an idea", meta: "Mel makes a new folder for it", isOn: selected == nil) { isIdea = true }
            }
            Text("Or drop a project folder anywhere on this window.")
                .textStyle(Theme.Text.callout)
                .foregroundStyle(Theme.Colors.secondaryLabel)
        }
    }

    private func row(name: String, meta: String, isOn: Bool, pick: @escaping () -> Void) -> some View {
        Button(action: pick) {
            HStack(spacing: Theme.Space.x12) {
                Circle()
                    .strokeBorder(isOn ? Theme.Colors.accent : .clear, lineWidth: Theme.Size.startRadioRing)
                    .surface(Theme.Colors.background, isOn ? .init() : .startRadioOff, in: Circle())
                    .frame(width: Theme.Size.startRadio, height: Theme.Size.startRadio)
                VStack(alignment: .leading, spacing: 0) {
                    Text(name).textStyle(Theme.Text.bodyMedium).lineLimit(1)
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

    private var footNote: String {
        if !state.agent.isReady { return state.agent == .missing ? "Start works once an agent is found." : "Start works once Claude Code is ready." }
        return selected == nil
            ? "Mel learns your project from your first spec."
            : "Mel reads the project once in the background, about a minute. You can start writing right away."
    }

    private func start() {
        do {
            if let selected { try state.startProject(selected) }
            onStart(selected == nil)
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
