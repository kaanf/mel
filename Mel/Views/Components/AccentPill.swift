import SwiftUI
import MelSpec

/// The V2 accent pill: Start (34 pt) and "Build with Claude Code" (44 pt), with the shortcut as plain text after the label.
struct AccentPillStyle: ButtonStyle {
    var height: CGFloat = Theme.Size.buttonLarge
    var padding: CGFloat = Theme.Space.x18
    /// "↩" or "⌘↩".
    var hint: String?
    var text = Theme.Text.bodyBold
    var hintText = Theme.Text.caption
    var gap: CGFloat = Theme.Space.x8
    var elevation = Theme.Elevation()

    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: gap) {
            configuration.label.textStyle(text)
            if let hint {
                Text(hint).textStyle(hintText).opacity(0.85).accessibilityHidden(true)
            }
        }
        .foregroundStyle(Theme.Colors.onAccent)
        .padding(.horizontal, padding)
        .frame(height: height)
        .surface(isEnabled ? Theme.Colors.accent : Theme.Colors.tertiary, isEnabled ? elevation : .init(), in: Capsule())
        .opacity(configuration.isPressed ? 0.85 : 1)
        .contentShape(Capsule())
    }
}

extension AgentStatus {
    var isReady: Bool {
        if case .ready = self { true } else { false }
    }

    var executablePath: String? {
        switch self {
        case .ready(let url, _), .notSignedIn(let url): url.path(percentEncoded: false)
        default: nil
        }
    }

    /// "Ready", "Not signed in"…: the sidebar's agent line and Settings › Agents.
    var word: String {
        switch self {
        case .ready: "Ready"
        case .notSignedIn: "Not signed in"
        case .checking: "Checking"
        case .missing: "Not found"
        case .broken: "Not working"
        }
    }
}

extension String {
    /// "/Users/me/.local/bin/claude" → "~/.local/bin/claude"
    var abbreviatingHome: String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path(percentEncoded: false)
        let trimmed = home.hasSuffix("/") ? String(home.dropLast()) : home
        return hasPrefix(trimmed + "/") || self == trimmed ? "~" + dropFirst(trimmed.count) : self
    }
}

#Preview("Accent pills") {
    VStack(spacing: Theme.Space.x16) {
        Button("Start") {}.buttonStyle(AccentPillStyle(hint: "↩"))
        Button("Start") {}.buttonStyle(AccentPillStyle(padding: Theme.Space.x16, hint: "⌘↩")).disabled(true)
        Button("Build with Claude Code") {}
            .buttonStyle(AccentPillStyle(height: Theme.Size.buildButton, padding: Theme.Space.x24, hint: "⌘↩", text: Theme.Text.buildButton, hintText: Theme.Text.callout, gap: Theme.Space.x10, elevation: .buildButton))
    }
    .padding(Theme.Space.x32)
    .background(Theme.Colors.background)
}
