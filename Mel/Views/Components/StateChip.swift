import SwiftUI

/// A screen state from EXPERIENCE.md; one written `!Error` is missing and reads "Error missing".
struct StateChip: View {
    let state: String

    var body: some View {
        if state.hasPrefix("!") {
            Text("\(state.dropFirst()) missing")
                .textStyle(Theme.Text.captionBold)
                .foregroundStyle(Theme.Colors.cautionText)
                .padding(.horizontal, Theme.Space.x8)
                .frame(height: Theme.Size.badge)
                .surface(Theme.Colors.background, .missingBadge, in: Capsule())
        } else {
            Text(state)
                .textStyle(Theme.Text.caption)
                .padding(.horizontal, Theme.Space.x8)
                .frame(height: Theme.Size.badge)
                .background(Theme.Colors.chipFill, in: Capsule())
        }
    }
}
