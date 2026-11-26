import SwiftUI
import MelSpec
import UniformTypeIdentifiers

/// What the Updates group shows and does; App/ fills it from Sparkle so views never import it.
struct UpdateSettings {
    var version: String               // "0.2 (build 123)"
    var canCheck: Bool                // false while Sparkle is already checking
    var automaticallyChecks: Binding<Bool>
    var check: () -> Void
}

/// Settings (⌘,): General, Agents and Specs. Advanced is drawn as a tab but has nothing in it yet, so it is hidden.
struct SettingsView: View {
    enum Pane: String { case general, agents, specs }

    let updates: UpdateSettings
    /// Remembered, and set by the links that open Settings on a pane ("Change in Settings").
    @AppStorage("settingsTab") private var pane = Pane.agents

    var body: some View {
        TabView(selection: $pane) {
            Tab("General", systemImage: "gearshape", value: Pane.general) { GeneralSettings(updates: updates) }
            Tab("Agents", systemImage: "apple.terminal", value: Pane.agents) { AgentSettings() }
            Tab("Specs", systemImage: "doc.text", value: Pane.specs) { SpecsSettings() }
        }
    }
}

/// Settings › General: updates (not drawn; the Agents pane's look).
struct GeneralSettings: View {
    let updates: UpdateSettings

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.x6) {
            Text("Updates").textStyle(Theme.Text.bodyBold).padding(.horizontal, Theme.Space.x12).accessibilityAddTraits(.isHeader)
            VStack(spacing: 0) {
                HStack(spacing: Theme.Space.x8) {
                    Text("Version \(updates.version)").textStyle(Theme.Text.body).frame(maxWidth: .infinity, alignment: .leading)
                    Button("Check for Updates…", action: updates.check)
                        .buttonStyle(DesignButtonStyle(role: .secondary, height: Theme.Size.buttonTiny, leading: Theme.Space.x10, trailing: Theme.Space.x10, text: Theme.Text.callout))
                        .disabled(!updates.canCheck)
                }
                .padding(.horizontal, Theme.Space.x12)
                .frame(height: Theme.Size.upNextRow)
                Rectangle().fill(Theme.Colors.separator).frame(height: Theme.Size.hairline).padding(.leading, Theme.Space.x12)
                HStack(spacing: Theme.Space.x8) {
                    Text("Automatically check for updates").textStyle(Theme.Text.body).frame(maxWidth: .infinity, alignment: .leading)
                    Toggle("Automatically check for updates", isOn: updates.automaticallyChecks)
                        .toggleStyle(DesignSwitchStyle())
                        .labelsHidden()
                }
                .padding(.horizontal, Theme.Space.x12)
                .frame(height: Theme.Size.upNextRow)
            }
            .background(Theme.Colors.fill, in: RoundedRectangle(cornerRadius: Theme.Radius.box))
        }
        .foregroundStyle(Theme.Colors.label)
        .padding(EdgeInsets(top: Theme.Space.x20, leading: Theme.Space.x24, bottom: Theme.Space.x24, trailing: Theme.Space.x24))
        .frame(width: Theme.Size.settingsWidth)
        .fixedSize(horizontal: false, vertical: true)
        .background(Theme.Colors.background)
    }
}

/// Settings › Agents (design/v2 Native-Settings-Agents): Claude Code's card, detection paths, Scan Now.
/// Hidden: Codex, per-agent on/off and the scan-on-launch switch (Mel always scans at launch).
struct AgentSettings: View {
    @Environment(AppState.self) private var state
    @State private var picking: Pick?
    @State private var selectedPath: Int?

    private enum Pick { case executable, folder }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.x20) {
            agentCard
            group("Detection") { searchPaths }
            HStack {
                Spacer()
                Button("Scan Now") { Task { await state.scanForAgent() } }
                    .buttonStyle(DesignButtonStyle(role: .secondary, height: Theme.Size.button, leading: Theme.Space.x16, trailing: Theme.Space.x16, text: Theme.Text.body))
                    .disabled(state.agent == .checking)
            }
        }
        .foregroundStyle(Theme.Colors.label)
        .padding(EdgeInsets(top: Theme.Space.x20, leading: Theme.Space.x24, bottom: Theme.Space.x24, trailing: Theme.Space.x24))
        .frame(width: Theme.Size.settingsWidth)
        .fixedSize(horizontal: false, vertical: true)
        .background(Theme.Colors.background)
        .fileImporter(
            isPresented: Binding(get: { picking != nil }, set: { if !$0 { picking = nil } }),
            allowedContentTypes: picking == .folder ? [.folder] : [.unixExecutable]
        ) { result in
            guard case .success(let url) = result else { return }
            let folder = picking == .folder ? url : url.deletingLastPathComponent()
            state.extraSearchPaths.append(folder.path(percentEncoded: false))
            Task { await state.scanForAgent() }
        }
    }

    private func group(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: Theme.Space.x6) {
            Text(title).textStyle(Theme.Text.bodyBold).padding(.horizontal, Theme.Space.x12).accessibilityAddTraits(.isHeader)
            content().background(Theme.Colors.fill, in: RoundedRectangle(cornerRadius: Theme.Radius.box))
        }
    }

    private var separator: some View {
        Rectangle().fill(Theme.Colors.separator).frame(height: Theme.Size.hairline)
    }

    // MARK: Agent

    private var agentCard: some View {
        VStack(spacing: 0) {
            HStack(spacing: Theme.Space.x10) {
                DesignIcon(glyph: .terminal, size: Theme.Size.checkIcon, weight: 1.7)
                    .foregroundStyle(Theme.Colors.onAccent)
                    .frame(width: Theme.Size.agentCardTile, height: Theme.Size.agentCardTile)
                    .background(Theme.Colors.agentTile, in: RoundedRectangle(cornerRadius: Theme.Radius.code))
                    .accessibilityHidden(true)
                Text("Claude Code").textStyle(Theme.Text.bodyBold).frame(maxWidth: .infinity, alignment: .leading)
                HStack(spacing: Theme.Space.x6) {
                    if state.agent.isReady {
                        DesignIcon(glyph: .check, size: Theme.Size.smallCheck, weight: 2.2).foregroundStyle(Theme.Colors.success)
                    } else {
                        StatusDot(style: .ring(Theme.Colors.secondaryLabel))
                    }
                    Text(state.agent.word).textStyle(Theme.Text.callout)
                }
                .accessibilityElement(children: .combine)
            }
            .padding(.horizontal, Theme.Space.x12)
            .frame(height: Theme.Size.agentCardRow)
            separator.padding(.leading, Theme.Size.agentDetailIndent)
            detailRow("Location") {
                Text(state.agent.executablePath.map { $0.abbreviatingHome } ?? "Not found")
                    .textStyle(Theme.Text.codeCaption)
                    .foregroundStyle(Theme.Colors.secondaryLabel)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Button("Change…") { picking = .executable }
                    .buttonStyle(DesignButtonStyle(role: .secondary, height: Theme.Size.buttonTiny, leading: Theme.Space.x10, trailing: Theme.Space.x10, text: Theme.Text.callout))
            }
            separator.padding(.leading, Theme.Size.agentDetailIndent)
            detailRow("Account") {
                Text(account).textStyle(Theme.Text.body).foregroundStyle(Theme.Colors.secondaryLabel).frame(maxWidth: .infinity, alignment: .leading)
                Button("Open Terminal…", action: state.signIn)
                    .buttonStyle(DesignLinkStyle())
            }
        }
        .background(Theme.Colors.fill, in: RoundedRectangle(cornerRadius: Theme.Radius.box))
    }

    private func detailRow(_ label: String, @ViewBuilder content: () -> some View) -> some View {
        HStack(spacing: Theme.Space.x8) {
            Text(label).textStyle(Theme.Text.body).frame(width: Theme.Size.agentDetailLabel, alignment: .leading)
            content()
        }
        .padding(.leading, Theme.Size.agentDetailIndent)
        .padding(.trailing, Theme.Space.x12)
        .frame(height: Theme.Size.agentDetailRow)
    }

    private var account: String {
        switch state.agent {
        case .ready: "Signed in through the CLI"
        case .notSignedIn: "Not signed in"
        default: "Unknown"
        }
    }

    // MARK: Detection

    private var searchPaths: some View {
        @Bindable var state = state
        return VStack(alignment: .leading, spacing: Theme.Space.x8) {
            Text("Search paths").textStyle(Theme.Text.body)
            VStack(spacing: 0) {
                Text("Your login shell’s PATH")
                    .textStyle(Theme.Text.callout)
                    .padding(.horizontal, Theme.Space.x10)
                    .frame(maxWidth: .infinity, minHeight: Theme.Size.pathRow, alignment: .leading)
                ForEach(state.extraSearchPaths.indices, id: \.self) { index in
                    Button { selectedPath = index } label: {
                        Text(state.extraSearchPaths[index].abbreviatingHome)
                            .textStyle(Theme.Text.codeCaption)
                            .padding(.horizontal, Theme.Space.x10)
                            .frame(maxWidth: .infinity, minHeight: Theme.Size.pathRow, alignment: .leading)
                            .background(selectedPath == index ? Theme.Colors.selectionFill : index % 2 == 0 ? Theme.Colors.fieldFill : .clear)
                            .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(selectedPath == index ? .isSelected : [])
                }
                HStack(spacing: 0) {
                    Button { picking = .folder } label: { pathButton(.plus) }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Add search path")
                    Rectangle().fill(Theme.Colors.toolbarDivider).frame(width: Theme.Size.hairline, height: Theme.Space.x14)
                    Button {
                        if let selectedPath, state.extraSearchPaths.indices.contains(selectedPath) { state.extraSearchPaths.remove(at: selectedPath) }
                        selectedPath = nil
                    } label: { pathButton(.minus) }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Remove search path")
                        .disabled(selectedPath == nil)
                    Spacer()
                }
                .frame(height: Theme.Size.pathFooter)
                .overlay(alignment: .top) { separator }
            }
            .surface(Theme.Colors.background, .menu, in: RoundedRectangle(cornerRadius: Theme.Radius.field))
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.field))
            Text("Apps opened from the Dock don’t see your Terminal PATH, so it is read from your login shell.")
                .textStyle(Theme.Text.caption)
                .foregroundStyle(Theme.Colors.secondaryLabel)
        }
        .padding(EdgeInsets(top: Theme.Space.x10, leading: Theme.Space.x12, bottom: Theme.Space.x12, trailing: Theme.Space.x12))
    }

    private func pathButton(_ glyph: DesignIcon.Glyph) -> some View {
        DesignIcon(glyph: glyph, size: Theme.Size.smallCheck, weight: 1.8)
            .foregroundStyle(Theme.Colors.label)
            .frame(width: Theme.Size.pathButton, height: Theme.Size.pathFooter)
            .contentShape(.rect)
    }
}

#Preview("Agents, ready") {
    AgentSettings().environment(PreviewData.appState(agent: PreviewData.ready))
}

#Preview("Agents, not signed in") {
    AgentSettings().environment(PreviewData.appState(agent: PreviewData.notSignedIn))
}

#Preview("Agents, not found") {
    AgentSettings().environment(PreviewData.appState(agent: .missing))
}

#Preview("General") {
    GeneralSettings(updates: PreviewData.updates())
}

#Preview("General, checking for updates") {
    GeneralSettings(updates: PreviewData.updates(canCheck: false, automaticallyChecks: false))
}

#Preview("Tabs") {
    SettingsView(updates: PreviewData.updates()).environment(PreviewData.appState([], contexts: [PreviewData.project.id: PreviewData.context]))
}
