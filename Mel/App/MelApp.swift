import SwiftUI
import MelAgent

@main
struct MelApp: App {
    @State private var state = AppState(
        adapter: ClaudeCode(),
        makeRunner: { AgentRunner(adapter: ClaudeCode(), executable: $0) }
    )
    @State private var isShowingNewSpec = false

    var body: some Scene {
        WindowGroup {
            MainView(isShowingNewSpec: $isShowingNewSpec)
                .environment(state)
        }
        .commands {
            MelCommands(isShowingNewSpec: $isShowingNewSpec, canCreateSpec: state.agent.isReady)
        }

        Window("Welcome", id: "welcome") {
            WelcomeView()
                .environment(state)
        }
        .windowResizability(.contentSize)
        .windowStyle(.hiddenTitleBar)

        Settings {
            SettingsView()
                .environment(state)
        }
    }
}
