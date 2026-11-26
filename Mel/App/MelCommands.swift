import SwiftUI

/// Check for Updates… and ⌘N New.
struct MelCommands: Commands {
    @Binding var isShowingNew: Bool
    let canCreateSpec: Bool
    let updater: Updater

    var body: some Commands {
        CommandGroup(after: .appInfo) {
            Button("Check for Updates…", action: updater.checkForUpdates)
                .disabled(!updater.canCheckForUpdates)
        }
        CommandGroup(replacing: .newItem) {
            Button("New") { isShowingNew = true }
                .keyboardShortcut("n")
                .disabled(!canCreateSpec)
        }
    }
}
