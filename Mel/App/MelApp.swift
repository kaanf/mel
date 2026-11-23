import SwiftUI
import MelAgent

@main
struct MelApp: App {
    @State private var state = AppState(
        adapter: ClaudeCode(),
        makeRunner: { AgentRunner(adapter: ClaudeCode(), executable: $0) }
    )

    var body: some Scene {
        WindowGroup {
            Text("Mel")
        }
    }
}
