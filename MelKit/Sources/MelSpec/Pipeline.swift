import Foundation

/// Inputs to the pipeline (V2.md §5).
public enum PipelineEvent: Hashable, Sendable {
    /// Every coverage topic is covered, or the user clicked Draft Now.
    case discoveryFinished
    case draftFinished
    case draftStopped(StopReason)
    case resume
    case finishByHand
    /// Works with assumptions and open questions left (OQ #18).
    case approve(DocKind)
    /// The user saved an edit to this file.
    case edited(DocKind)
    /// Revise these files in file order (round-2 or open-question answer, analyze fix).
    case revise([DocKind])
    /// C1 "Refine n Files": accept the edits, revise every stale file.
    case refine
    /// C1 "Keep Them as They Are": accept the edits, clear `stale`.
    case keepAsIs
    /// C1 Undo: the snapshot is back on disk.
    case undo(DocKind)
    case analyzeFinished(AnalyzeResult)
    case analyzeFailed
    case rerunAnalyze
    /// B6 "Hand Off Anyway", or Passed → B7.
    case handOff
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

        case (_, .approve(let kind)):
            guard docs[kind] == .review else { return false }
            docs[kind] = .approved
            // Re-approving a file outside the current step doesn't move the pipeline.
            if stage == .review(kind) { advance() }

        case (_, .edited(let kind)):
            guard docs[kind] == .approved else { return false }
            docs[kind] = .edited
            for later in files(after: kind) where docs[later] == .approved { docs[later] = .stale }
            if analyze != .locked { analyze = .stale }

        case (_, .revise(let kinds)):
            guard !isRunning, let first = kinds.first,
                  kinds.allSatisfy({ [.review, .approved, .edited, .stale].contains(docs[$0]) }) else { return false }
            queue = Array(kinds.dropFirst()) + queue.filter { !kinds.contains($0) }
            startDrafting(first)

        case (_, .refine):
            guard !isRunning, hasEdits else { return false }
            acceptEdits()
            let stale = size.files.filter { docs[$0] == .stale }
            guard let first = stale.first else { return true }
            queue = Array(stale.dropFirst()) + queue.filter { !stale.contains($0) }
            startDrafting(first)

        case (_, .keepAsIs):
            guard hasEdits else { return false }
            acceptEdits()
            for kind in size.files where docs[kind] == .stale { docs[kind] = .approved }

        case (_, .undo(let kind)):
            guard docs[kind] == .edited else { return false }
            docs[kind] = .approved
            for later in files(after: kind) where docs[later] == .stale && !files(before: later).contains(where: { docs[$0] == .edited }) {
                docs[later] = .approved
            }
            if analyze == .stale, !hasEdits { analyze = analysis.map(Self.status) ?? .locked }

        case (.analyze, .analyzeFinished(let result)):
            guard analyze == .running else { return false }
            analysis = result
            analyze = Self.status(result)

        case (.analyze, .analyzeFailed):
            guard analyze == .running else { return false }
            analyze = .stale

        case (.analyze, .rerunAnalyze), (.done, .rerunAnalyze):
            guard size.hasAnalyze, analyze != .running, size.files.allSatisfy({ docs[$0] == .approved }) else { return false }
            stage = .analyze
            analyze = .running

        case (.analyze, .handOff):
            guard analyze != .running else { return false }
            stage = .done

        default:
            return false
        }
        return true
    }

    /// A file is being written or waits for Continue.
    private var isRunning: Bool {
        switch stage {
        case .drafting, .stopped: true
        default: false
        }
    }

    private var hasEdits: Bool { docs.values.contains { $0 == .edited || $0 == .stale } }

    /// After an approval: the next queued revise, else a file still in review, else the next
    /// locked file, else Analyze (done for Quick fix).
    private mutating func advance() {
        if !queue.isEmpty {
            startDrafting(queue.removeFirst())
        } else if let kind = size.files.first(where: { docs[$0] == .review }) {
            stage = .review(kind)
        } else if let kind = size.files.first(where: { docs[$0] == .locked }) {
            startDrafting(kind)
        } else if size.hasAnalyze {
            stage = .analyze
            // Over an edited or stale file Analyze waits for C1, shown as Rerun.
            analyze = hasEdits ? .stale : .running
        } else {
            stage = .done
        }
    }

    private mutating func startDrafting(_ kind: DocKind) {
        stage = .drafting(kind)
        docs[kind] = .writing
    }

    private mutating func acceptEdits() {
        for kind in size.files where docs[kind] == .edited { docs[kind] = .approved }
    }

    private func files(after kind: DocKind) -> ArraySlice<DocKind> {
        size.files.drop { $0 != kind }.dropFirst()
    }

    private func files(before kind: DocKind) -> ArraySlice<DocKind> {
        size.files.prefix { $0 != kind }
    }

    private static func status(_ result: AnalyzeResult) -> AnalyzeStatus {
        result.issues.isEmpty ? .passed : .issues(result.issues.count)
    }
}
