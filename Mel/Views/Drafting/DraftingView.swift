import SwiftUI
import MelSpec

/// The agent writing one file: running or stopped. A stop the user didn't ask for opens the failure sheet.
struct DraftingView: View {
    let session: SpecSession
    let kind: DocKind
    @Binding var showInspector: Bool
    @State private var dismissedFailure = false
    @State private var width: CGFloat = .infinity

    private var spec: Spec { session.spec }

    private var stopReason: StopReason? {
        if case .stopped(let stopped, let reason) = spec.stage, stopped == kind { reason } else { nil }
    }

    private var isStopped: Bool { !session.isRunning && spec.docs[kind] == .stopped }

    private var failure: StopReason? {
        guard let stopReason, stopReason != .user, !dismissedFailure else { return nil }
        return stopReason
    }

    private var compact: Bool { width < ToolbarStatus.fullTextWidth }

    @ViewBuilder
    private var status: some View {
        if isStopped {
            ToolbarStatus(status: .stopped)
        } else {
            ToolbarStatus(status: .checking, title: "Running", detail: session.activity.last?.text ?? "Starting", compact: compact)
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                StageStepper(steps: ["Idea", "Questions", "Draft \(kind.title)", "Review"], current: 2)
                if isStopped {
                    stoppedBanner
                }
                GroupBox("\(kind.fileName) · Claude Code") {
                    steps.frame(maxWidth: .infinity, alignment: .leading)
                }
                DisclosureGroup("Activity Log") {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(session.activity) { line in
                            Text("\(Text(line.at, format: .dateTime.hour().minute().second()).foregroundStyle(.secondary))  \(line.text)")
                        }
                    }
                    .font(.callout.monospaced())
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                upNext
                if !isStopped {
                    Text("You can switch apps. You'll get a notification when \(kind.title) is ready to review.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: 620)
            .padding(24)
            .frame(maxWidth: .infinity)
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            ProgressStrip(isRunning: !isStopped)
        }
        .navigationTitle("Drafting")
        .navigationSubtitle(spec.name)
        .toolbar {
            // Two items, not one: NSToolbar doesn't widen an item whose content grows.
            if compact {
                ToolbarItem(placement: .status) { status }
            } else {
                ToolbarItem(placement: .status) { status }
            }
            if !isStopped {
                ToolbarItem {
                    Button("Stop", systemImage: "stop.fill") { Task { await session.stop() } }
                        .help("Stop the agent. What it wrote so far is kept.")
                }
            }
            ToolbarItem {
                Button("Inspector", systemImage: "sidebar.trailing") { showInspector.toggle() }
                    .help("Show or hide the live preview")
            }
        }
        .inspector(isPresented: $showInspector) {
            LivePreview(text: session.liveText, kind: kind, isRunning: !isStopped)
                .inspectorColumnWidth(min: 280, ideal: 340)
        }
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = $0 }
        .focusedSceneValue(\.inspectorShown, $showInspector)
        .sheet(isPresented: Binding(get: { failure != nil }, set: { if !$0 { dismissedFailure = true } })) {
            if let failure {
                FailureSheet(session: session, kind: kind, reason: failure)
            }
        }
    }

    private var stoppedBanner: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 10) {
                Label("Stopped. Nothing was lost.", systemImage: "pause.circle.fill")
                    .font(.headline)
                    .foregroundStyle(.orange)
                Text("What the agent wrote so far is saved in \(kind.fileName). You can review it now or let the agent continue.")
                HStack {
                    Button("Continue Drafting") { Task { await session.resume() } }
                        .buttonStyle(.borderedProminent)
                    Button("Review What's Written") { session.finishByHand() }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    /// Each activity line is a finished step; the last row is the one in progress or where it stopped.
    private var steps: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(session.activity) { line in
                Label(line.text, systemImage: "checkmark")
                    .foregroundStyle(.secondary)
            }
            if isStopped {
                StatusBadge(status: .stopped)
            } else {
                StatusBadge(status: .checking, title: "Writing")
            }
        }
    }

    @ViewBuilder
    private var upNext: some View {
        let later = DocKind.allCases.drop { $0 != kind }.dropFirst()
        if !later.isEmpty {
            GroupBox("Up Next") {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(Array(later), id: \.self) { next in
                        let previous = DocKind.allCases[DocKind.allCases.firstIndex(of: next)! - 1]
                        LabeledContent(next.fileName, value: "Starts after you approve \(previous.title)")
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}

/// Rendered, read-only view of the file while the agent writes it.
struct LivePreview: View {
    let text: String
    let kind: DocKind
    let isRunning: Bool
    @State private var blocks: [Block] = []

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text("Live Preview")
                    .font(.headline)
                MarkdownBlocksView(blocks: blocks)
                if isRunning {
                    Text("▍")
                        .foregroundStyle(.purple)
                        .accessibilityHidden(true)
                }
                Text("Read only while the agent writes. You can edit once it's ready for review.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .defaultScrollAnchor(.bottom)
        .task(id: text) {
            blocks = await parseDocument(text, kind: kind).0
        }
    }
}

#Preview("Running") {
    @Previewable @State var showInspector = true
    NavigationStack {
        DraftingView(session: PreviewData.session(PreviewData.drafting, isRunning: true), kind: .requirements, showInspector: $showInspector)
    }
    .frame(width: 1100, height: 760)
}

#Preview("Stopped") {
    @Previewable @State var showInspector = false
    NavigationStack {
        DraftingView(session: PreviewData.session(PreviewData.stoppedByUser), kind: .requirements, showInspector: $showInspector)
    }
    .frame(width: 800, height: 760)
}

#Preview("Usage limit") {
    @Previewable @State var showInspector = false
    NavigationStack {
        DraftingView(session: PreviewData.session(PreviewData.usageLimit), kind: .design, showInspector: $showInspector)
    }
    .environment(PreviewData.appState([PreviewData.usageLimit]))
    .frame(width: 800, height: 760)
}

#Preview("Live preview") {
    LivePreview(text: PreviewData.requirementsMarkdown, kind: .requirements, isRunning: true)
        .frame(width: 340, height: 600)
}
