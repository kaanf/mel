import SwiftUI
import MelSpec

/// A1 Welcome (design/v2 Native-0-Welcome): the coding agent found on this Mac. Codex is hidden in v0.3.
struct WelcomeView: View {
    @Environment(AppState.self) private var state
    let onContinue: () -> Void

    var body: some View {
        ZStack(alignment: .top) {
            Image(.logo)
                .resizable()
                .interpolation(.high)
                .frame(width: Theme.Size.logoLarge, height: Theme.Size.logoLarge)
                .shadow(Theme.LogoShadow.large)
                .padding(.top, Theme.Size.welcomeLogoTop)
                .accessibilityHidden(true)

            VStack(spacing: Theme.Space.x22) {
                VStack(spacing: Theme.Space.x8) {
                    Text("Welcome to Mel")
                        .textStyle(Theme.Text.title2)
                        .foregroundStyle(Theme.Colors.label)
                        .accessibilityAddTraits(.isHeader)
                    Text("Specs are written by the coding agents already on your Mac, using your own accounts. Here is what we found.")
                        .textStyle(Theme.Text.body)
                        .foregroundStyle(Theme.Colors.secondaryLabel)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: Theme.Size.welcomeTextWidth)
                }
                SetupAgentRow(status: state.agent, onSignIn: state.signIn)
                    .background(Theme.Colors.fill, in: RoundedRectangle(cornerRadius: Theme.Radius.card))
                VStack(spacing: Theme.Space.x8) {
                    Button("Continue", action: onContinue)
                        .buttonStyle(DesignButtonStyle(leading: Theme.Space.x22, trailing: Theme.Space.x14, keyHint: "↩"))
                        .keyboardShortcut(.defaultAction)
                    Text("Next, pick a project folder. Mel reads it once.")
                        .textStyle(Theme.Text.caption)
                        .foregroundStyle(Theme.Colors.secondaryLabel)
                }
            }
            .frame(maxWidth: Theme.Size.welcomeWidth)
            .padding(.top, Theme.Size.welcomeContentTop)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .setupChrome(stepLabel: "Setup")
    }
}

/// Agent row of A1: dark tile, name, path, status (design: 52 pt row in a #F5F5F7 box).
struct SetupAgentRow: View {
    let status: AgentStatus
    let onSignIn: () -> Void

    var body: some View {
        HStack(spacing: Theme.Space.x10) {
            AgentTile()
            VStack(alignment: .leading, spacing: Theme.Space.x1) {
                Text("Claude Code")
                    .textStyle(Theme.Text.bodyMedium)
                    .foregroundStyle(Theme.Colors.label)
                if let path = status.executablePath {
                    Text(path.abbreviatingHome)
                        .textStyle(Theme.Text.codeCaption)
                        .foregroundStyle(Theme.Colors.secondaryLabel)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            trailing
        }
        .padding(.horizontal, Theme.Space.x12)
        .frame(height: Theme.Size.agentRow)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var trailing: some View {
        HStack(spacing: Theme.Space.x6) {
            switch status {
            case .ready:
                DesignIcon(glyph: .check, size: Theme.Size.checkIcon).foregroundStyle(Theme.Colors.success)
                Text("Ready").textStyle(Theme.Text.callout).foregroundStyle(Theme.Colors.label)
            case .checking:
                StatusDot(style: .running)
                Text("Checking").textStyle(Theme.Text.callout).foregroundStyle(Theme.Colors.secondaryLabel)
            case .notSignedIn:
                StatusDot(style: .ring(Theme.Colors.secondaryLabel))
                Text("Not signed in").textStyle(Theme.Text.callout).foregroundStyle(Theme.Colors.secondaryLabel)
                Button("Sign In", action: onSignIn).buttonStyle(DesignLinkStyle())
            case .missing:
                StatusDot(style: .ring(Theme.Colors.secondaryLabel))
                Text("Not found").textStyle(Theme.Text.callout).foregroundStyle(Theme.Colors.secondaryLabel)
            case .broken:
                StatusDot(style: .filled(Theme.Colors.caution))
                Text("Not working").textStyle(Theme.Text.callout).foregroundStyle(Theme.Colors.secondaryLabel)
            }
        }
    }
}

/// 30 pt dark tile with the terminal prompt.
struct AgentTile: View {
    var body: some View {
        DesignIcon(glyph: .terminal, size: Theme.Size.terminalIcon)
            .foregroundStyle(Theme.Colors.onAccent)
            .frame(width: Theme.Size.agentTile, height: Theme.Size.agentTile)
            .background(Theme.Colors.label, in: RoundedRectangle(cornerRadius: Theme.Radius.field))
            .accessibilityHidden(true)
    }
}

extension String {
    /// "/Users/me/.local/bin/claude" → "~/.local/bin/claude"
    var abbreviatingHome: String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path(percentEncoded: false)
        let trimmed = home.hasSuffix("/") ? String(home.dropLast()) : home
        return hasPrefix(trimmed + "/") ? "~" + dropFirst(trimmed.count) : self
    }
}

#Preview("Ready") {
    WelcomeView(onContinue: {})
        .environment(PreviewData.appState(agent: PreviewData.ready))
        .frame(width: Theme.Size.windowWidth, height: Theme.Size.windowHeight - Theme.Size.toolbar)
}

#Preview("Checking") {
    WelcomeView(onContinue: {})
        .environment(PreviewData.appState(agent: .checking))
        .frame(width: Theme.Size.windowWidth, height: Theme.Size.windowHeight - Theme.Size.toolbar)
}

#Preview("Not signed in") {
    WelcomeView(onContinue: {})
        .environment(PreviewData.appState(agent: PreviewData.notSignedIn))
        .frame(width: Theme.Size.windowWidth, height: Theme.Size.windowHeight - Theme.Size.toolbar)
}

#Preview("Not working") {
    WelcomeView(onContinue: {})
        .environment(PreviewData.appState(agent: .broken("claude exited with status 127")))
        .frame(width: Theme.Size.windowWidth, height: Theme.Size.windowHeight - Theme.Size.toolbar)
}
