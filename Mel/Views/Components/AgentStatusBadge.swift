import SwiftUI
import MelSpec

extension AgentStatus {
    var isReady: Bool {
        if case .ready = self { true } else { false }
    }

    var executablePath: String? {
        switch self {
        case .ready(let url, _), .notSignedIn(let url): url.path(percentEncoded: false)
        default: nil
        }
    }
}

struct AgentStatusBadge: View {
    let status: AgentStatus

    var body: some View {
        switch status {
        case .checking: StatusBadge(status: .checking)
        case .ready: StatusBadge(status: .ready)
        case .notSignedIn: StatusBadge(status: .needsYou, title: "Not signed in")
        case .missing: StatusBadge(status: .stopped, title: "Not found")
        case .broken: StatusBadge(status: .stopped, title: "Not working")
        }
    }
}

extension DocStatus {
    var badge: StatusBadge {
        switch self {
        case .locked: StatusBadge(status: .locked)
        case .writing: StatusBadge(status: .checking, title: "Writing")
        case .stopped: StatusBadge(status: .stopped)
        case .review: StatusBadge(status: .needsYou, title: "Review")
        case .approved: StatusBadge(status: .approved)
        }
    }
}

/// Claude Code row used by Welcome: icon, name, path, status and the action that fixes it.
struct AgentRow: View {
    let status: AgentStatus
    let onSignIn: () -> Void
    let onChoose: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "terminal")
                .font(.title2)
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text("Claude Code")
                if let path = status.executablePath {
                    Text(path)
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
            }
            Spacer()
            AgentStatusBadge(status: status)
            switch status {
            case .notSignedIn: Button("Sign In…", action: onSignIn)
            case .missing, .broken: Button("Choose File…", action: onChoose)
            case .checking, .ready: EmptyView()
            }
        }
    }
}

#Preview {
    Form {
        AgentRow(status: PreviewData.ready, onSignIn: {}, onChoose: {})
        AgentRow(status: .checking, onSignIn: {}, onChoose: {})
        AgentRow(status: PreviewData.notSignedIn, onSignIn: {}, onChoose: {})
        AgentRow(status: .missing, onSignIn: {}, onChoose: {})
    }
    .formStyle(.grouped)
    .frame(width: 560)
}
