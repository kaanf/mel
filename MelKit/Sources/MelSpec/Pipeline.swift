import Foundation

/// Inputs to the pipeline (DESIGN.md › Pipeline).
public enum PipelineEvent: Hashable, Sendable {
    /// Every coverage topic is covered, or the user clicked Draft Now.
    case discoveryFinished
    case draftFinished
    case draftStopped(StopReason)
    case resume
    case finishByHand
    /// `assumptionsLeft` is the number of `[!ASSUMPTION]` callouts still in the file.
    case approve(DocKind, assumptionsLeft: Int)
    /// The user saved an edit to this file.
    case edited(DocKind)
}

extension Spec {
    /// Applies `event` and returns true, or returns false and leaves the spec unchanged
    /// when the event isn't allowed in the current stage.
    @discardableResult
    public mutating func apply(_ event: PipelineEvent) -> Bool {
        switch (stage, event) {
        case (.discovery, .discoveryFinished):
            startDrafting(size.files[0])

        case (.drafting(let kind), .draftFinished),
             (.stopped(let kind, _), .finishByHand):
            stage = .review(kind)
            docs[kind] = .review

        case (.drafting(let kind), .draftStopped(let reason)):
            stage = .stopped(kind, reason)
            docs[kind] = .stopped

        case (.stopped(let kind, _), .resume):
            startDrafting(kind)

        case (_, .approve(let kind, let left)):
            guard docs[kind] == .review, left == 0 else { return false }
            docs[kind] = .approved
            // Re-approving an earlier file after an edit doesn't move the pipeline.
            guard stage == .review(kind) else { return true }
            if let next = size.file(after: kind) { startDrafting(next) } else { stage = .done }

        case (_, .edited(let kind)):
            // Editing an approved file sends it back to review; nothing else cascades.
            guard docs[kind] == .approved else { return false }
            docs[kind] = .review

        default:
            return false
        }
        return true
    }

    private mutating func startDrafting(_ kind: DocKind) {
        stage = .drafting(kind)
        docs[kind] = .writing
    }
}
