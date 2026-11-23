import SwiftUI
import MelSpec
import UniformTypeIdentifiers

/// First launch: shows what was found for Claude Code and how to fix it.
struct WelcomeView: View {
    @Environment(AppState.self) private var state
    @Environment(\.dismissWindow) private var dismissWindow
    @AppStorage("didShowWelcome") private var didShowWelcome = false
    @State private var choosingFile = false

    var body: some View {
        VStack(spacing: 16) {
            // App icon arrives in Wave 3.
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 56))
                .foregroundStyle(.tint)
                .accessibilityHidden(true)
            Text("Welcome")
                .font(.largeTitle.bold())
            Text("Specs are written by the coding agent already on your Mac, using your own account. Here is what we found.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Form {
                Section {
                    AgentRow(status: state.agent, onSignIn: state.signIn) { choosingFile = true }
                } header: {
                    HStack {
                        Text("Coding Agent")
                        Spacer()
                        Button("Scan Again") { Task { await state.scanForAgent() } }
                            .buttonStyle(.link)
                            .disabled(state.agent == .checking)
                    }
                } footer: {
                    Text("Sign In opens Terminal with Claude Code's own login command. Not installed? Install it, then Scan Again, or choose the file manually.")
                }
            }
            .formStyle(.grouped)
            .scrollDisabled(true)
            .frame(height: 190)
            HStack {
                Text("You can change this later in Settings › Agents.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Spacer()
                Button(state.agent.isReady ? "Continue" : "Continue Without Agent") {
                    didShowWelcome = true
                    dismissWindow()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 600)
        .fileImporter(isPresented: $choosingFile, allowedContentTypes: [.unixExecutable]) { result in
            guard case .success(let url) = result else { return }
            state.extraSearchPaths.append(url.deletingLastPathComponent().path(percentEncoded: false))
            Task { await state.scanForAgent() }
        }
    }
}

#Preview("Ready") {
    WelcomeView().environment(PreviewData.appState(agent: PreviewData.ready))
}

#Preview("Checking") {
    WelcomeView().environment(PreviewData.appState(agent: .checking))
}

#Preview("Not signed in") {
    WelcomeView().environment(PreviewData.appState(agent: PreviewData.notSignedIn))
}

#Preview("Not found") {
    WelcomeView().environment(PreviewData.appState(agent: .missing))
}
