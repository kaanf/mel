import SwiftUI

/// Status symbol plus label, using the colors from docs/UI.md.
struct StatusBadge: View {
    enum Status: Hashable {
        case ready, checking, needsYou, stopped, locked, approved

        var title: String {
            switch self {
            case .ready: "Ready"
            case .checking: "Checking"
            case .needsYou: "Needs you"
            case .stopped: "Stopped"
            case .locked: "Locked"
            case .approved: "Approved"
            }
        }

        var symbol: String {
            switch self {
            case .ready, .approved: "checkmark.circle.fill"
            case .checking: "circle.fill"
            case .needsYou, .stopped: "exclamationmark.circle.fill"
            case .locked: "lock.fill"
            }
        }

        var color: Color {
            switch self {
            case .ready, .approved: .green
            case .checking: .purple
            case .needsYou, .stopped: .orange
            case .locked: .secondary
            }
        }
    }

    let status: Status
    var title: String?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Label {
            Text(title ?? status.title)
        } icon: {
            Image(systemName: status.symbol)
                .foregroundStyle(status.color)
                .imageScale(status == .checking ? .small : .medium)
                .symbolEffect(.pulse, isActive: status == .checking && !reduceMotion)
        }
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 8) {
        StatusBadge(status: .ready)
        StatusBadge(status: .checking)
        StatusBadge(status: .needsYou)
        StatusBadge(status: .stopped)
        StatusBadge(status: .locked)
        StatusBadge(status: .approved)
        StatusBadge(status: .needsYou, title: "Not signed in")
    }
    .padding()
}
