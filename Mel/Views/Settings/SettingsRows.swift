import SwiftUI

/// A Settings row (V2-6): label and note on the left, its control on the right.
func settingsRow(_ label: String, _ note: String, @ViewBuilder control: () -> some View) -> some View {
    HStack(spacing: Theme.Space.x12) {
        VStack(alignment: .leading, spacing: Theme.Space.x2) {
            Text(label).textStyle(Theme.Text.body)
            Text(note).textStyle(Theme.Text.captionLoose).foregroundStyle(Theme.Colors.secondaryLabel)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        control()
    }
    .padding(.vertical, Theme.Space.x8)
    .padding(.horizontal, Theme.Space.x12)
    .frame(minHeight: Theme.Size.specsSettingsRow)
}

/// The drawn pop-up button: the value and the two arrows, over a menu of `items`.
func settingsValue(_ text: String, @ViewBuilder items: () -> some View) -> some View {
    Menu {
        items().pickerStyle(.inline).labelsHidden()
    } label: {
        HStack(spacing: Theme.Space.x6) {
            Text(text).textStyle(Theme.Text.callout)
            DesignIcon(glyph: .popUp, size: Theme.Size.readyCheck, weight: 1.6)
                .frame(width: Theme.Size.selectArrowWidth)
                .foregroundStyle(Theme.Colors.secondaryLabel)
        }
        .foregroundStyle(Theme.Colors.label)
        .padding(.horizontal, Theme.Space.x8)
        .frame(height: Theme.Size.buttonMini)
        .surface(Theme.Colors.background, .settingsValue, in: RoundedRectangle(cornerRadius: Theme.Radius.code))
        .contentShape(RoundedRectangle(cornerRadius: Theme.Radius.code))
    }
    .menuStyle(.button)
    .buttonStyle(.plain)
    .menuIndicator(.hidden)
    .fixedSize()
}
