import SwiftUI
import AppKit
import MelAgent

@main
struct MelApp: App {
    @State private var state = Self.makeState()
    @State private var updater = Updater()
    /// V2-1 New in the main window's detail; ⌘N and the sidebar's New set it.
    @State private var isShowingNew = Self.startsOnNew
    /// Settings › General › Appearance, applied to every window (Settings too).
    @AppStorage("appearance") private var appearance = Appearance.system

    var body: some Scene {
        WindowGroup {
            MainView(isShowingNew: $isShowingNew)
                .environment(state)
                .task {
                    #if DEBUG
                    if DebugScreen.current != nil { return }   // keep the fixture's agent
                    #endif
                    await state.scanForAgent()
                }
                .onChange(of: appearance, initial: true) { _, appearance in
                    NSApp.appearance = switch appearance {
                    case .system: nil
                    case .light: NSAppearance(named: .aqua)
                    case .dark: NSAppearance(named: .darkAqua)
                    }
                }
        }
        // No toolbar: in full screen macOS draws it as a band of its own over every column. Each
        // column has its own header row instead.
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: Theme.Size.windowWidth, height: Theme.Size.windowHeight)
        .commands {
            MelCommands(isShowingNew: $isShowingNew, canCreateSpec: state.currentProject != nil, updater: updater)
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

    private static var startsOnNew: Bool {
        #if DEBUG
        DebugScreen.current == .new || DebugScreen.current == .newEmpty || DebugScreen.current == .newSplit
        #else
        false
        #endif
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
