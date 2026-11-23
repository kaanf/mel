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
        // Not a Label: toolbars render Labels icon-only, and the text is the point.
        HStack(spacing: 5) {
            Image(systemName: status.symbol)
                .foregroundStyle(status.color)
                .imageScale(status == .checking ? .small : .medium)
                .symbolEffect(.pulse, isActive: status == .checking && !reduceMotion)
                .accessibilityHidden(true)
            Text(title ?? status.title)
                .lineLimit(1)
                .truncationMode(.tail)
        }
        .accessibilityElement(children: .combine)
    }
}

/// Status in a window toolbar: "Title · detail", or just "Title" when `compact`.
/// AppKit moves a toolbar item that doesn't fit at its ideal width into the » overflow
/// (ViewThatFits doesn't help there), so the screen measures its width and passes `compact`.
struct ToolbarStatus: View {
    let status: StatusBadge.Status
    var title: String?
    var detail: String?
    var compact = false

    /// Detail-area width (content plus inspector) below which the full text no longer fits
    /// next to the title and the other toolbar buttons. Measured in the Debug app.
    static let fullTextWidth: CGFloat = 660

    var body: some View {
        StatusBadge(status: status, title: compact || detail == nil ? title : "\(title ?? status.title) · \(detail!)")
            .padding(.horizontal, 10)   // the glass capsule adds no inset of its own
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

#Preview("Toolbar status, full and compact") {
    VStack(alignment: .leading, spacing: 8) {
        ToolbarStatus(status: .needsYou, detail: "Claude Code is waiting for an answer")
        ToolbarStatus(status: .needsYou, detail: "Claude Code is waiting for an answer", compact: true)
    }
    .padding()
}
