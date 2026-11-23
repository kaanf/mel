import SwiftUI

/// Spec progress (design/v2 B2, B3): Idea › Intake › Draft › Review. Done steps get a green check,
/// the current one a filled dot and bold text, later ones a grey ring; 16 pt lines between.
struct StageStepper: View {
    let steps: [String]
    let current: Int

    init(steps: [String] = ["Idea", "Intake", "Draft", "Review"], current: Int) {
        self.steps = steps
        self.current = current
    }

    var body: some View {
        HStack(spacing: Theme.Space.x8) {
            ForEach(steps.indices, id: \.self) { index in
                if index > 0 {
                    Rectangle()
                        .fill(Theme.Colors.stepConnector)
                        .frame(width: Theme.Space.x16, height: Theme.Size.hairline)
                        .accessibilityHidden(true)
                }
                step(index)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Spec progress")
        .accessibilityValue(steps.indices.contains(current) ? steps[current] : "")
    }

    private func step(_ index: Int) -> some View {
        HStack(spacing: Theme.Space.x6) {
            if index < current {
                DesignIcon(glyph: .check, size: Theme.Size.smallCheck, weight: 2.2)
                    .foregroundStyle(Theme.Colors.success)
            } else if index == current {
                Circle().fill(Theme.Colors.label).frame(width: Theme.Size.statusDot, height: Theme.Size.statusDot)
            } else {
                StatusDot(style: .ring(Theme.Colors.secondaryLabel))
            }
            Text(steps[index])
                .textStyle(index == current ? Theme.Text.calloutBold : Theme.Text.callout)
                .foregroundStyle(index == current ? Theme.Colors.label : Theme.Colors.secondaryLabel)
        }
    }
}

#Preview {
    VStack(alignment: .leading, spacing: Theme.Space.x12) {
        StageStepper(steps: ["Idea", "Intake 2 of 5", "Draft", "Review"], current: 1)
        StageStepper(steps: ["Idea", "Intake", "Draft REQUIREMENTS.md", "Review"], current: 2)
        StageStepper(current: 3)
    }
    .padding()
    .background(Theme.Colors.background)
}
