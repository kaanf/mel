import SwiftUI
import MelSpec

/// Shown when the agent stops on its own (usage limit, sign-out, crash, timeout).
struct FailureSheet: View {
    let session: SpecSession
    let kind: DocKind
    let reason: StopReason
    @Environment(AppState.self) private var state
    @Environment(\.dismiss) private var dismiss
    @State private var finishMyself = false
    @State private var showDetails = false
    @State private var summary = DocSummary()

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.largeTitle)
                    .foregroundStyle(.orange)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 6) {
                    Text("Claude Code stopped while writing \(kind.fileName)")
                        .font(.headline)
                    Text(explanation)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            GroupBox {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(DocKind.allCases, id: \.self) { doc in
                        LabeledContent(doc.fileName) {
                            Text(fileState(doc))
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            Text("What should happen next?")
                .font(.headline)
            VStack(spacing: 2) {
                RadioRow(label: resumeOption, isSelected: !finishMyself) { finishMyself = false }
                RadioRow(label: "Finish \(kind.fileName) myself", isSelected: finishMyself) { finishMyself = true }
            }
            if showDetails {
                Text(details)
                    .font(.callout.monospaced())
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            HStack {
                Button(showDetails ? "Hide Details" : "Show Details") { showDetails.toggle() }
                Spacer()
                Button("Not Now") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button(primaryTitle, action: primary)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 480)
        .task {
            summary = await parseDocument(session.documents[kind] ?? "", kind: kind).1
        }
    }

    private var explanation: String {
        let unchanged = "Nothing you approved was changed."
        switch reason {
        case .usageLimit(let resetsAt):
            let reset = resetsAt.map { " It resets at \($0.formatted(date: .omitted, time: .shortened))." } ?? ""
            return "Your plan's usage limit was reached. This is a limit on your Claude account, not a problem with the spec.\(reset) \(unchanged)"
        case .signedOut: return "Claude Code is no longer signed in. \(unchanged)"
        case .crashed: return "Claude Code quit unexpectedly. \(unchanged)"
        case .timeout: return "Claude Code stopped responding. \(unchanged)"
        case .user, .sessionNotFound: return unchanged
        }
    }

    private var resumeOption: String {
        switch reason {
        case .usageLimit: "Resume with Claude Code when the limit resets"
        case .signedOut: "Sign in, then resume"
        default: "Resume now"
        }
    }

    private var primaryTitle: String {
        if finishMyself { return "Open File" }
        switch reason {
        case .usageLimit: return "Resume Later"
        case .signedOut: return "Sign In…"
        default: return "Resume"
        }
    }

    private func primary() {
        if finishMyself {
            session.finishByHand()
        } else if reason == .signedOut {
            state.signIn()
        } else {
            Task { await session.resume() }
        }
        dismiss()
    }

    private var details: String {
        if case .crashed(let message) = reason { return message }
        return session.activity.suffix(5).map(\.text).joined(separator: "\n")
    }

    private func fileState(_ doc: DocKind) -> String {
        switch session.spec.docs[doc] ?? .locked {
        case .approved: "Approved, unchanged"
        case .stopped: "Stopped. \(summary.line(for: doc)) saved"
        case .writing: "Writing"
        case .review: "Ready for review"
        case .locked: "Not started"
        case .edited: "Edited"
        case .stale: "Out of date"
        }
    }
}

#Preview("Usage limit") {
    FailureSheet(session: PreviewData.session(PreviewData.usageLimit), kind: .architecture, reason: .usageLimit(resetsAt: Date(timeIntervalSince1970: 1_795_000_000)))
        .environment(PreviewData.appState([PreviewData.usageLimit]))
}

#Preview("Crashed") {
    FailureSheet(session: PreviewData.session(PreviewData.crashed), kind: .architecture, reason: .crashed("claude exited with status 1"))
        .environment(PreviewData.appState([PreviewData.crashed]))
}

#Preview("Signed out") {
    FailureSheet(session: PreviewData.session(PreviewData.usageLimit), kind: .architecture, reason: .signedOut)
        .environment(PreviewData.appState([PreviewData.usageLimit]))
}
