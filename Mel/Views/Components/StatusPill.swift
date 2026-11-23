import SwiftUI

/// Toolbar status pill (design/v2 B2–B5): what the agent is doing and "n of m" files.
struct StatusPill: View {
    enum Indicator: Hashable {
        /// Grey ring: idle, paused or stopped.
        case idle
        /// Pulsing purple dot: the agent is writing.
        case running
        /// #C93400 alert: the agent waits for an answer.
        case needsYou
    }

    let indicator: Indicator
    /// "Needs you · Claude Code is waiting for an answer"
    let text: String
    /// "2 of 5"
    let count: String
    /// B3: share of the file written, drawn as a 2 pt bar along the bottom (purple while running).
    var progress: Double?
    /// The design sets one per screen: `Theme.Size.statusPill…`.
    let maxWidth: CGFloat

    var body: some View {
        HStack(spacing: Theme.Space.x8) {
            switch indicator {
            case .idle: StatusDot(style: .ring(Theme.Colors.secondaryLabel))
            case .running: StatusDot(style: .running)
            case .needsYou: DesignIcon(glyph: .alert, size: Theme.Size.alertIcon).foregroundStyle(Theme.Colors.caution)
            }
            Text(text)
                .textStyle(Theme.Text.callout)
                .foregroundStyle(Theme.Colors.label)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(count)
                .textStyle(Theme.Text.caption)
                .foregroundStyle(Theme.Colors.secondaryLabel)
                .fixedSize()
        }
        .padding(.horizontal, Theme.Space.x14)
        .frame(maxWidth: maxWidth)
        .frame(height: Theme.Size.chip)
        .overlay(alignment: .bottomLeading) {
            if let progress {
                GeometryReader { proxy in
                    Rectangle()
                        .fill(indicator == .running ? Theme.Colors.drafting : Theme.Colors.tertiary)
                        .frame(width: proxy.size.width * min(max(progress, 0), 1), height: Theme.Size.progressBar)
                        .frame(maxHeight: .infinity, alignment: .bottom)
                }
            }
        }
        .surface(Theme.Colors.statusPillFill, .outlineFaint, in: Capsule())
        .clipShape(Capsule())
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.updatesFrequently)
    }
}

#Preview("States") {
    VStack(spacing: Theme.Space.x16) {
        StatusPill(indicator: .needsYou, text: "Needs you · Claude Code is waiting for an answer", count: "2 of 5", maxWidth: Theme.Size.statusPillIntake)
        StatusPill(indicator: .running, text: "Running · Writing criteria for story 3 of 5", count: "2 of 5", progress: 0.46, maxWidth: Theme.Size.statusPillDrafting)
        StatusPill(indicator: .idle, text: "Stopped · 2 stories saved", count: "2 of 5", progress: 0.46, maxWidth: Theme.Size.statusPillDrafting)
        StatusPill(indicator: .idle, text: "Idle · EXPERIENCE.md starts when you approve", count: "2 of 5", maxWidth: Theme.Size.statusPillReview)
        StatusPill(indicator: .idle, text: "Idle · ARCHITECTURE.md starts when you approve", count: "3 of 5", maxWidth: Theme.Size.statusPillExperience)
    }
    .padding(Theme.Space.x24)
    .frame(width: 440)
    .background(Theme.Colors.background)
}
