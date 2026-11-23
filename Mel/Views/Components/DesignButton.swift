import SwiftUI

/// Capsule buttons of design/v2: accent (white text) or white (label text), with an optional key hint.
struct DesignButtonStyle: ButtonStyle {
    enum Role { case primary, secondary }

    var role: Role = .primary
    /// Height: `Theme.Size.buttonLarge` (34), `.buttonToolbar` (32), `.button` (28), `.buttonMini` (24).
    var height: CGFloat = Theme.Size.buttonLarge
    /// Horizontal padding as drawn, e.g. 22/14 for A1 Continue with its ↩ hint.
    var leading: CGFloat = Theme.Space.x22
    var trailing: CGFloat = Theme.Space.x22
    /// "↩" or "⌘↩", drawn as a translucent key cap on accent buttons.
    var keyHint: String?
    var text: Theme.TextStyle = Theme.Text.bodyBold
    /// Overrides the shadow picked from role and height (A2 "Start from an Idea" is 30 pt with the small-button shadow).
    var elevation: Theme.Elevation?

    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: Theme.Space.x8) {
            configuration.label
                .textStyle(text)
            if let keyHint {
                Text(keyHint)
                    .textStyle(Theme.Text.captionMedium)
                    .padding(.horizontal, Theme.Space.x5)
                    .background(Theme.Colors.keyHintOnAccent, in: RoundedRectangle(cornerRadius: Theme.Radius.keyHint))
            }
        }
        .foregroundStyle(role == .primary ? Theme.Colors.onAccent : Theme.Colors.label)
        .padding(.leading, leading)
        .padding(.trailing, trailing)
        .frame(height: height)
        .surface(fill, elevation ?? defaultElevation, in: Capsule())
        .opacity(configuration.isPressed ? 0.85 : 1)
        .contentShape(Capsule())
    }

    private var fill: Color {
        switch role {
        case .primary: isEnabled ? Theme.Colors.accent : Theme.Colors.tertiary
        case .secondary: Theme.Colors.background
        }
    }

    private var defaultElevation: Theme.Elevation {
        switch (role, height) {
        case (.primary, Theme.Size.buttonLarge): isEnabled ? .primaryLarge : .init()
        case (.primary, Theme.Size.buttonToolbar): .primaryToolbar
        case (.primary, _): .primary
        case (.secondary, Theme.Size.buttonLarge): .buttonSmall
        case (.secondary, Theme.Size.buttonToolbar): .buttonToolbar
        case (.secondary, _): .button
        }
    }
}

/// Text link in the design's link blue (#0066D6).
struct DesignLinkStyle: ButtonStyle {
    var text: Theme.TextStyle = Theme.Text.callout

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .textStyle(text)
            .foregroundStyle(Theme.Colors.link)
            .opacity(configuration.isPressed ? 0.7 : 1)
            .contentShape(Rectangle())
    }
}

#Preview("Buttons") {
    VStack(spacing: Theme.Space.x16) {
        Button("Continue") {}.buttonStyle(DesignButtonStyle(leading: Theme.Space.x22, trailing: Theme.Space.x14, keyHint: "↩"))
        Button("Check Again") {}.buttonStyle(DesignButtonStyle())
        Button("Read This Repo") {}.buttonStyle(DesignButtonStyle(leading: Theme.Space.x20, trailing: Theme.Space.x20)).disabled(true)
        Button("Approve") {}.buttonStyle(DesignButtonStyle(height: Theme.Size.buttonToolbar, leading: Theme.Space.x16, trailing: Theme.Space.x16, keyHint: "⌘↩"))
        Button("Decide Later") {}.buttonStyle(DesignButtonStyle(role: .secondary, height: Theme.Size.button, leading: Theme.Space.x16, trailing: Theme.Space.x16, text: Theme.Text.body))
        Button("Copy") {}.buttonStyle(DesignButtonStyle(role: .secondary, height: Theme.Size.buttonMini, leading: Theme.Space.x10, trailing: Theme.Space.x10, text: Theme.Text.callout))
        Button("Look around first") {}.buttonStyle(DesignLinkStyle())
    }
    .padding(Theme.Space.x32)
    .background(Theme.Colors.background)
}
