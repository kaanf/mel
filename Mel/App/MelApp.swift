import SwiftUI
import MelAgent

@main
struct MelApp: App {
    @State private var state = AppState(
        adapter: ClaudeCode(),
        makeRunner: { AgentRunner(adapter: ClaudeCode(), executable: $0) }
    )
    @State private var updater = Updater()
    @State private var isShowingNewSpec = false

    var body: some Scene {
        WindowGroup {
            MainView(isShowingNewSpec: $isShowingNewSpec)
                .environment(state)
                .task { await state.scanForAgent() }
        }
        .commands {
            MelCommands(isShowingNewSpec: $isShowingNewSpec, canCreateSpec: state.agent.isReady, updater: updater)
        }

        Window("Welcome", id: "welcome") {
            WelcomeView()
                .environment(state)
        }
        .windowResizability(.contentSize)
        .windowStyle(.hiddenTitleBar)

        Settings {
            SettingsView(updates: UpdateSettings(
                version: Self.version,
                canCheck: updater.canCheckForUpdates,
                automaticallyChecks: $updater.automaticallyChecksForUpdates,
                check: updater.checkForUpdates
            ))
                .environment(state)
        }
    }

    /// "0.2 (build 123)" from Info.plist.
    private static var version: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "?"
        let build = info?["CFBundleVersion"] as? String ?? "?"
        return "\(short) (build \(build))"
    }
}
