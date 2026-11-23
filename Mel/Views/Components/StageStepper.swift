import SwiftUI

/// Idea › Questions › Draft › Review, with steps before `current` checked.
struct StageStepper: View {
    let steps: [String]
    let current: Int

    init(steps: [String] = ["Idea", "Questions", "Draft", "Review"], current: Int) {
        self.steps = steps
        self.current = current
    }

    var body: some View {
        HStack(spacing: 6) {
            ForEach(steps.indices, id: \.self) { index in
                if index > 0 {
                    Image(systemName: "chevron.forward")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .accessibilityHidden(true)
                }
                step(index)
            }
        }
        .font(.callout)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private func step(_ index: Int) -> some View {
        if index < current {
            Label(steps[index], systemImage: "checkmark")
                .foregroundStyle(.secondary)
                .accessibilityLabel("\(steps[index]), done")
        } else if index == current {
            Text(steps[index])
                .fontWeight(.semibold)
                .foregroundStyle(.tint)
                .accessibilityLabel("\(steps[index]), current step")
        } else {
            Text(steps[index])
                .foregroundStyle(.tertiary)
        }
    }
}
