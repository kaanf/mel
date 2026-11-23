import SwiftUI

/// 8 pt status dot of the sidebar and the toolbar pill (design/v2 B2–C3).
struct StatusDot: View {
    enum Style: Hashable {
        /// Filled: Approved (green), Out of date (#B25000), issues and Stopped (#C93400).
        case filled(Color)
        /// 1.5 pt ring: Review and Edited (#1D1D1F), idle pill (#6E6E73).
        case ring(Color)
        /// 1.5 pt dashed grey ring: Locked and Queued.
        case dashed
        /// Pulsing purple: the agent is writing.
        case running
    }

    let style: Style

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulse = false

    var body: some View {
        dot
            .frame(width: Theme.Size.statusDot, height: Theme.Size.statusDot)
            .accessibilityHidden(true)
    }

    @ViewBuilder
    private var dot: some View {
        switch style {
        case .filled(let color):
            Circle().fill(color)
        case .ring(let color):
            Circle().strokeBorder(color, lineWidth: Theme.Size.statusDotStroke)
        case .dashed:
            Circle().strokeBorder(Theme.Colors.tertiary, style: StrokeStyle(
                lineWidth: Theme.Size.statusDotStroke, dash: Theme.Size.statusDotDash, dashPhase: Theme.Size.statusDotDashPhase
            ))
        case .running:
            // design: @keyframes pulse, scale 0.7 and opacity 0.55 at 50 %, 1.4 s
            Circle().fill(Theme.Colors.drafting)
                .scaleEffect(pulse ? 0.7 : 1)
                .opacity(pulse ? 0.55 : 1)
                .onAppear {
                    guard !reduceMotion else { return }
                    withAnimation(.timingCurve(0.4, 0, 0.2, 1, duration: 0.7).repeatForever()) { pulse = true }
                }
        }
    }
}

#Preview("Styles") {
    HStack(spacing: Theme.Space.x12) {
        StatusDot(style: .filled(Theme.Colors.success))
        StatusDot(style: .ring(Theme.Colors.label))
        StatusDot(style: .dashed)
        StatusDot(style: .filled(Theme.Colors.warning))
        StatusDot(style: .filled(Theme.Colors.caution))
        StatusDot(style: .running)
    }
    .padding(Theme.Space.x20)
    .background(Theme.Colors.background)
}
