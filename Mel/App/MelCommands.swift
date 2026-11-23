import SwiftUI

/// Check for Updates…, ⌘N New Spec, ⌘↩ Approve, ⌥⌘I inspector.
struct MelCommands: Commands {
    @Binding var isShowingNewSpec: Bool
    let canCreateSpec: Bool
    let updater: Updater
    @FocusedValue(\.approve) private var approve
    @FocusedValue(\.inspectorShown) private var inspectorShown

    var body: some Commands {
        CommandGroup(after: .appInfo) {
            Button("Check for Updates…", action: updater.checkForUpdates)
                .disabled(!updater.canCheckForUpdates)
        }
        CommandGroup(replacing: .newItem) {
            Button("New Spec…") { isShowingNewSpec = true }
                .keyboardShortcut("n")
                .disabled(!canCreateSpec)
        }
        CommandMenu("Spec") {
            Button("Approve") { approve?() }
                .keyboardShortcut(.return, modifiers: .command)
                .disabled(approve == nil)
        }
        CommandGroup(after: .sidebar) {
            Button(inspectorShown?.wrappedValue == true ? "Hide Inspector" : "Show Inspector") {
                inspectorShown?.wrappedValue.toggle()
            }
            .keyboardShortcut("i", modifiers: [.command, .option])
            .disabled(inspectorShown == nil)
        }
    }
}
