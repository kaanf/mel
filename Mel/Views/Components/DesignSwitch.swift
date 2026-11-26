import SwiftUI

/// The design's switch (Settings): 32 × 18 track, 14 pt white knob.
struct DesignSwitchStyle: ToggleStyle {
    /// Track when off: 0.12 as drawn on the older screens, 0.14 in Settings › Specs.
    var offFill = Theme.Colors.switchOffFill

    func makeBody(configuration: Configuration) -> some View {
        Button { configuration.isOn.toggle() } label: {
            Capsule()
                .fill(configuration.isOn ? Theme.Colors.accent : offFill)
                .frame(width: Theme.Size.switchWidth, height: Theme.Size.switchHeight)
                .overlay(alignment: configuration.isOn ? .trailing : .leading) {
                    Color.clear
                        .surface(Theme.Colors.background, .switchKnob, in: Circle())
                        .frame(width: Theme.Size.switchKnob, height: Theme.Size.switchKnob)
                        .padding(Theme.Space.x2)
                }
                .animation(.timingCurve(0.25, 0.46, 0.45, 0.94, duration: 0.15), value: configuration.isOn)
        }
        .buttonStyle(.plain)
        .accessibilityRepresentation { Toggle(isOn: configuration.$isOn) { configuration.label } }
    }
}

#Preview("Switch") {
    @Previewable @State var on = true
    @Previewable @State var off = false
    VStack(spacing: Theme.Space.x16) {
        Toggle("On", isOn: $on)
        Toggle("Off", isOn: $off)
    }
    .toggleStyle(DesignSwitchStyle())
    .padding(Theme.Space.x32)
    .background(Theme.Colors.background)
}
