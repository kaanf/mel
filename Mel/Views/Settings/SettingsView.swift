import SwiftUI
import MelSpec
import UniformTypeIdentifiers

struct SettingsView: View {
    var body: some View {
        TabView {
            Tab("General", systemImage: "gearshape") { NotDesignedYet() }
            Tab("Agents", systemImage: "terminal") { AgentsSettingsView() }
            Tab("Specs", systemImage: "folder") { NotDesignedYet() }
            Tab("Advanced", systemImage: "gearshape.2") { NotDesignedYet() }
        }
        .frame(width: 560)
    }
}

/// General, Specs and Advanced wait for a design decision (docs/UI.md › Settings).
private struct NotDesignedYet: View {
    var body: some View {
        ContentUnavailableView("No Settings Yet", systemImage: "gearshape")
            .frame(height: 240)
    }
}

struct AgentsSettingsView: View {
    @Environment(AppState.self) private var state
    @AppStorage("scanOnLaunch") private var scanOnLaunch = true
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
                Toggle("Look for the agent when the app opens", isOn: $scanOnLaunch)
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
        }
        .formStyle(.grouped)
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
    SettingsView().environment(PreviewData.appState(agent: PreviewData.ready))
}

#Preview("Not signed in") {
    AgentsSettingsView().environment(PreviewData.appState(agent: PreviewData.notSignedIn))
        .frame(width: 560, height: 520)
}

#Preview("Not found") {
    AgentsSettingsView().environment(PreviewData.appState(agent: .missing))
        .frame(width: 560, height: 520)
}
