import SwiftUI
import MelSpec

/// C2 Agent stopped (design/v2 Native-Error-Partial): the agent stopped on its own (usage limit,
/// sign-out, crash, timeout). Every file's state, the recovery choices. Continue with Codex is hidden (V2 §2).
struct FailureSheet: View {
    let session: SpecSession
    let kind: DocKind
    let reason: StopReason
    @Environment(AppState.self) private var state
    @Environment(\.dismiss) private var dismiss
    @State private var finishMyself = false
    @State private var showDetails = false

    private var steps: [String] { kind.draftSteps }
    /// Where it stopped: `draftStep` is the last step marker reached, 1-based.
    private var stoppedAt: Int { min(max(session.draftStep, 1), steps.count) }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.x16) {
            HStack(alignment: .top, spacing: Theme.Space.x12) {
                Image("Logo")
                    .resizable()
                    .frame(width: Theme.Size.dialogLogo, height: Theme.Size.dialogLogo)
                    .overlay(alignment: .bottomTrailing) { AlertBadge().offset(x: Theme.Space.x6, y: Theme.Space.x6) }
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: Theme.Space.x4) {
                    Text("Claude Code stopped while writing \(kind.fileName)")
                        .textStyle(Theme.Text.sectionTitle)
                        .accessibilityAddTraits(.isHeader)
                    Text(explanation)
                        .textStyle(Theme.Text.body)
                        .foregroundStyle(Theme.Colors.secondaryLabel)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            fileList
            VStack(alignment: .leading, spacing: Theme.Space.x2) {
                Text("What should happen next?")
                    .textStyle(Theme.Text.bodyBold)
                    .padding(.bottom, Theme.Space.x4)
                RadioRow(label: resumeOption, note: resumeNote, isSelected: !finishMyself, insets: Self.choiceInsets) { finishMyself = false }
                RadioRow(label: "Finish \(kind.fileName) myself", note: "Opens the partial file for editing. The agent waits.", isSelected: finishMyself, insets: Self.choiceInsets) { finishMyself = true }
            }
            if showDetails {
                Text(details)
                    .textStyle(Theme.Text.codeCaptionLoose)
                    .foregroundStyle(Theme.Colors.secondaryLabel)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            HStack(spacing: Theme.Space.x8) {
                Button(showDetails ? "Hide Details" : "Show Details") { showDetails.toggle() }
                    .buttonStyle(DesignLinkStyle())
                Spacer()
                Button("Not Now") { dismiss() }
                    .buttonStyle(DesignButtonStyle(role: .secondary, height: Theme.Size.button, leading: Theme.Space.x16, trailing: Theme.Space.x16, text: Theme.Text.body))
                    .keyboardShortcut(.cancelAction)
                Button(primaryTitle, action: primary)
                    .buttonStyle(DesignButtonStyle(height: Theme.Size.button, leading: Theme.Space.x16, trailing: Theme.Space.x16))
                    .keyboardShortcut(.defaultAction)
            }
        }
        .foregroundStyle(Theme.Colors.label)
        .padding(Theme.Space.x20)
        .frame(width: Theme.Size.dialogWidth)
        .background(Theme.Colors.background)
    }

    private static let choiceInsets = EdgeInsets(top: Theme.Space.x6, leading: 0, bottom: Theme.Space.x6, trailing: 0)

    private var fileList: some View {
        let files = session.spec.size.files
        return VStack(spacing: 0) {
            ForEach(files.indices, id: \.self) { i in
                if i > 0 {
                    Rectangle().fill(Theme.Colors.separator).frame(height: Theme.Size.hairline).padding(.leading, Theme.Size.stepSeparatorInset)
                }
                fileRow(files[i])
            }
        }
        .background(Theme.Colors.fill, in: RoundedRectangle(cornerRadius: Theme.Radius.box))
    }

    private func fileRow(_ doc: DocKind) -> some View {
        let status = session.spec.docs[doc] ?? .locked
        return HStack(spacing: Theme.Space.x10) {
            Group {
                switch status {
                case .approved: DesignIcon(glyph: .check, size: Theme.Size.stepCheck, weight: 2.2).foregroundStyle(Theme.Colors.success)
                case .stopped: DesignIcon(glyph: .close, size: Theme.Size.stepCheck, weight: 2.2).foregroundStyle(Theme.Colors.failure)
                default: StatusDot(style: .ring(Theme.Colors.secondaryLabel))
                }
            }
            .frame(width: Theme.Size.stepCheck)
            Text(doc.fileName).textStyle(Theme.Text.code).frame(maxWidth: .infinity, alignment: .leading)
            Text(fileState(doc, status))
                .textStyle(Theme.Text.callout)
                .foregroundStyle(Theme.Colors.secondaryLabel)
                .multilineTextAlignment(.trailing)
        }
        .frame(minHeight: Theme.Size.stepRow - 2 * Theme.Space.x6)
        .padding(.vertical, Theme.Space.x6)
        .padding(.horizontal, Theme.Space.x12)
        .accessibilityElement(children: .combine)
    }

    private func fileState(_ doc: DocKind, _ status: DocStatus) -> String {
        switch status {
        case .approved: "Approved, unchanged"
        case .stopped:
            "Stopped at step \(stoppedAt) of \(steps.count)" + (stoppedAt > 1 ? "\n" + saved(stoppedAt - 1) : "")
        case .writing: "Writing"
        case .review: "Ready for review"
        case .locked: "Not started"
        case .edited: "Edited"
        case .stale: "Out of date"
        }
    }

    /// "Step 1 saved", "Steps 1 and 2 saved", "Steps 1 to 4 saved".
    private func saved(_ n: Int) -> String {
        n == 1 ? "Step 1 saved" : n == 2 ? "Steps 1 and 2 saved" : "Steps 1 to \(n) saved"
    }

    private var explanation: String {
        let unchanged = "Nothing you approved was changed."
        switch reason {
        case .usageLimit(let resetsAt):
            let reset = resetsAt.map { " It resets at \($0.formatted(date: .omitted, time: .shortened))." } ?? ""
            return "Claude Code reported that your plan’s usage limit was reached. This is a limit on your Claude account, not a problem with the spec.\(reset) \(unchanged)"
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

    private var resumeNote: String {
        reason.isUsageLimit ? "Continues from step \(stoppedAt). You’ll get a notification." : "Continues from step \(stoppedAt)."
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
        } else if reason.isUsageLimit {
            session.resumeLater()
        } else {
            Task { await session.resume() }
        }
        dismiss()
    }

    private var details: String {
        if case .crashed(let message) = reason { return message }
        return session.activity.suffix(5).map(\.text).joined(separator: "\n")
    }
}

private extension StopReason {
    var isUsageLimit: Bool { if case .usageLimit = self { true } else { false } }
}

/// The red alert badge on the dialog's logo (C2): white disc, filled triangle, white "!".
private struct AlertBadge: View {
    var body: some View {
        ZStack {
            Circle().fill(Theme.Colors.background).frame(width: Theme.Size.alertBadge - 2, height: Theme.Size.alertBadge - 2)
            SVGPathShape(data: "M12 4.5L20 18.5H4z", viewBox: CGSize(width: 24, height: 24))
                .fill(Theme.Colors.caution)
                .overlay { SVGPathShape(data: "M12 4.5L20 18.5H4z", viewBox: CGSize(width: 24, height: 24)).stroke(Theme.Colors.caution, style: StrokeStyle(lineWidth: 1.5, lineJoin: .round)) }
            SVGPathShape(data: "M12 9.5v4M12 16.2v.1", viewBox: CGSize(width: 24, height: 24))
                .stroke(Theme.Colors.background, style: StrokeStyle(lineWidth: 1.8, lineCap: .round))
        }
        .frame(width: Theme.Size.alertBadge, height: Theme.Size.alertBadge)
    }
}

#Preview("Usage limit") {
    FailureSheet(session: PreviewData.stoppedSession, kind: .architecture, reason: .usageLimit(resetsAt: nil))
        .environment(PreviewData.appState([PreviewData.usageLimit]))
}

#Preview("Crashed") {
    FailureSheet(session: PreviewData.session(PreviewData.crashed), kind: .architecture, reason: .crashed("claude exited with status 1"))
        .environment(PreviewData.appState([PreviewData.crashed]))
}

#Preview("Signed out") {
    FailureSheet(session: PreviewData.stoppedSession, kind: .architecture, reason: .signedOut)
        .environment(PreviewData.appState([PreviewData.usageLimit]))
}
