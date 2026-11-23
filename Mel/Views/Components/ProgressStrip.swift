import SwiftUI

/// Thin bar under the toolbar: purple while running, gray when stopped.
/// `value` nil shows an indeterminate pulse.
struct ProgressStrip: View {
    var value: Double?
    var isRunning = true

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Rectangle().fill(.quaternary)
                Rectangle()
                    .fill(isRunning ? AnyShapeStyle(.purple) : AnyShapeStyle(.gray))
                    .frame(width: proxy.size.width * min(max(value ?? 1, 0), 1))
                    .phaseAnimator([false, true]) { bar, phase in
                        bar.opacity(value == nil && isRunning && !reduceMotion && phase ? 0.3 : 1)
                    } animation: { _ in .easeInOut(duration: 0.9) }
            }
        }
        .frame(height: 3)
        .accessibilityElement()
        .accessibilityLabel(isRunning ? "Running" : "Stopped")
        .accessibilityValue(value.map { "\(Int($0 * 100)) percent" } ?? "")
    }
}
