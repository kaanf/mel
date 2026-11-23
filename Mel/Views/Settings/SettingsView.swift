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

/// Settings is Agents plus Updates (docs/UI.md › Settings).
struct SettingsView: View {
    let updates: UpdateSettings
    @Environment(AppState.self) private var state
    @State private var picking: Pick?

    private enum Pick { case executable, folder }

    var body: some View {
        @Bindable var state = state
        Form {
            Section("Claude Code") {
                LabeledContent("Status") { AgentStatusBadge(status: state.agent) }
                if case .ready(_, let version) = state.agent {
                    LabeledContent("Version", value: version)
                }
                LabeledContent("Location") {
                    HStack {
                        Text(state.agent.executablePath ?? "Not found")
                            .font(.callout.monospaced())
                            .textSelection(.enabled)
                        Button("Change…") { picking = .executable }
                    }
                }
                LabeledContent("Account") {
                    HStack {
                        Text(account)
                        Button("Open Terminal…", action: state.signIn)
                    }
                }
            }
            Section {
                LabeledContent("Search paths") {
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("Your login shell's PATH")
                            .foregroundStyle(.secondary)
                        ForEach(state.extraSearchPaths.indices, id: \.self) { index in
                            HStack {
                                Text(state.extraSearchPaths[index])
                                    .font(.callout.monospaced())
                                Button("Remove", systemImage: "minus") { state.extraSearchPaths.remove(at: index) }
                                    .labelStyle(.iconOnly)
                                    .buttonStyle(.borderless)
                            }
                        }
                        Button("Add Folder…", systemImage: "plus") { picking = .folder }
                    }
                }
            } header: {
                Text("Detection")
            } footer: {
                Text("Apps opened from the Dock don't see your Terminal PATH, so it is read from your login shell.")
            }
            Section {
                Button("Scan Now") { Task { await state.scanForAgent() } }
                    .disabled(state.agent == .checking)
            }
            Section("Updates") {
                Text("Version \(updates.version)")
                Toggle("Automatically check for updates", isOn: updates.automaticallyChecks)
                    .toggleStyle(.switch)
                Button("Check for Updates…", action: updates.check)
                    .disabled(!updates.canCheck)
            }
        }
        .formStyle(.grouped)
        .frame(width: 560)
        .fixedSize(horizontal: false, vertical: true)
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

    private var account: String {
        switch state.agent {
        case .ready: "Signed in through the CLI"
        case .notSignedIn: "Not signed in"
        default: "Unknown"
        }
    }
}

#Preview("Ready") {
    SettingsView(updates: PreviewData.updates()).environment(PreviewData.appState(agent: PreviewData.ready))
}

#Preview("Not signed in") {
    SettingsView(updates: PreviewData.updates()).environment(PreviewData.appState(agent: PreviewData.notSignedIn))
}

#Preview("Not found") {
    SettingsView(updates: PreviewData.updates()).environment(PreviewData.appState(agent: .missing))
}

#Preview("Checking for Updates") {
    SettingsView(updates: PreviewData.updates(canCheck: false, automaticallyChecks: false))
        .environment(PreviewData.appState(agent: PreviewData.ready))
}
