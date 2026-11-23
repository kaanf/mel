import SwiftUI
import MelSpec

/// A1x Welcome, no agent found (design/v2 Native-E1-NoAgents): install command, Check Again. Codex is hidden in v0.3.
struct NoAgentView: View {
    @Environment(AppState.self) private var state
    @Environment(\.openSettings) private var openSettings
    let onLookAround: () -> Void

    static let installCommand = "npm install -g @anthropic-ai/claude-code"

    var body: some View {
        VStack(spacing: Theme.Space.x22) {
            VStack(spacing: Theme.Space.x10) {
                Image(.logo)
                    .resizable()
                    .interpolation(.high)
                    .frame(width: Theme.Size.logoLarge, height: Theme.Size.logoLarge)
                    .shadow(Theme.LogoShadow.large)
                    .accessibilityHidden(true)
                Text("Welcome to Mel")
                    .textStyle(Theme.Text.title2)
                    .foregroundStyle(Theme.Colors.label)
                    .padding(.top, Theme.Space.x6)
                    .accessibilityAddTraits(.isHeader)
                Text("Mel doesn’t run its own AI. Your specs are written by a coding agent on this Mac, with your own account. We didn’t find one yet.")
                    .textStyle(Theme.Text.bodyLoose)
                    .foregroundStyle(Theme.Colors.bodyLabel)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: Theme.Size.noAgentTextWidth)
            }

            VStack(spacing: 0) {
                VStack(alignment: .leading, spacing: Theme.Space.x8) {
                    HStack(spacing: Theme.Space.x10) {
                        AgentTile()
                        VStack(alignment: .leading, spacing: Theme.Space.x1) {
                            Text("Claude Code").textStyle(Theme.Text.bodyMedium).foregroundStyle(Theme.Colors.label)
                            Text("Needs a Claude account").textStyle(Theme.Text.caption).foregroundStyle(Theme.Colors.secondaryLabel)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        HStack(spacing: Theme.Space.x6) {
                            StatusDot(style: .ring(Theme.Colors.secondaryLabel))
                            Text("Not found").textStyle(Theme.Text.callout).foregroundStyle(Theme.Colors.secondaryLabel)
                        }
                    }
                    .accessibilityElement(children: .combine)
                    HStack(spacing: Theme.Space.x8) {
                        Text(Self.installCommand)
                            .textStyle(Theme.Text.codeCaptionLoose)
                            .foregroundStyle(Theme.Colors.label)
                            .lineLimit(1)
                            .textSelection(.enabled)
                            .padding(EdgeInsets(top: Theme.Space.x6, leading: Theme.Space.x8, bottom: Theme.Space.x6, trailing: Theme.Space.x8))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .surface(Theme.Colors.background, .outline, in: RoundedRectangle(cornerRadius: Theme.Radius.code))
                        Button("Copy") { state.copy(Self.installCommand) }
                            .buttonStyle(DesignButtonStyle(role: .secondary, height: Theme.Size.buttonMini, leading: Theme.Space.x10, trailing: Theme.Space.x10, text: Theme.Text.callout))
                            .accessibilityLabel("Copy install command")
                    }
                    .padding(.leading, Theme.Size.agentTile + Theme.Space.x10)
                }
                .padding(Theme.Space.x12)
                .overlay(alignment: .bottom) {
                    Rectangle().fill(Theme.Colors.separatorLight).frame(height: Theme.Size.hairline)
                }
                Text("Install one in Terminal and sign in once. Mel checks again when you come back to this window.")
                    .textStyle(Theme.Text.captionLoose)
                    .foregroundStyle(Theme.Colors.secondaryLabel)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(EdgeInsets(top: Theme.Space.x10, leading: Theme.Space.x12, bottom: Theme.Space.x10, trailing: Theme.Space.x12))
            }
            .background(Theme.Colors.fill, in: RoundedRectangle(cornerRadius: Theme.Radius.card))

            VStack(spacing: Theme.Space.x10) {
                Button("Check Again") { Task { await state.scanForAgent() } }
                    .buttonStyle(DesignButtonStyle())
                    .keyboardShortcut(.defaultAction)
                    .disabled(state.agent == .checking)
                HStack(spacing: Theme.Space.x16) {
                    Button("Installed somewhere else? Choose path…") { openSettings() }
                    Button("Look around first", action: onLookAround)
                }
                .buttonStyle(DesignLinkStyle())
            }
        }
        .frame(maxWidth: Theme.Size.noAgentWidth)
        .padding(EdgeInsets(top: Theme.Space.x8, leading: Theme.Space.x24, bottom: Theme.Space.x40, trailing: Theme.Space.x24))
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .setupChrome(stepLabel: "Setup")
    }
}

#Preview("No agent") {
    NoAgentView(onLookAround: {})
        .environment(PreviewData.appState(agent: .missing))
        .frame(width: Theme.Size.windowWidth, height: Theme.Size.windowHeight - Theme.Size.toolbar)
}
