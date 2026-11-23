import SwiftUI
import MelAgent

@main
struct MelApp: App {
    @State private var state = Self.makeState()
    @State private var updater = Updater()
    @State private var isShowingNewSpec = false

    var body: some Scene {
        WindowGroup {
            MainView(isShowingNewSpec: $isShowingNewSpec)
                .environment(state)
                .task {
                    #if DEBUG
                    if DebugScreen.current != nil { return }   // keep the fixture's agent
                    #endif
                    await state.scanForAgent()
                }
        }
        .defaultSize(width: Theme.Size.windowWidth, height: Theme.Size.windowHeight)
        .commands {
            MelCommands(isShowingNewSpec: $isShowingNewSpec, canCreateSpec: state.agent.isReady, updater: updater)
        }


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

    private static func makeState() -> AppState {
        #if DEBUG
        if let screen = DebugScreen.current { return screen.state }
        #endif
        return AppState(adapter: ClaudeCode(), makeRunner: { AgentRunner(adapter: ClaudeCode(), executable: $0) })
    }

    /// "0.2 (build 123)" from Info.plist.
    private static var version: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "?"
        let build = info?["CFBundleVersion"] as? String ?? "?"
        return "\(short) (build \(build))"
    }
}
