import SwiftUI
import MelSpec

/// One finished file: rendered preview or editable Markdown, assumptions to confirm, Approve.
struct ReviewView: View {
    let session: SpecSession
    let kind: DocKind
    @State private var mode = Mode.preview
    @State private var text: String
    @State private var blocks: [Block] = []
    @State private var summary = DocSummary()
    @State private var editing: (index: Int, text: String)?
    @State private var editText = ""
    @State private var showReady = false

    enum Mode { case preview, edit }

    init(session: SpecSession, kind: DocKind, mode: Mode = .preview) {
        self.session = session
        self.kind = kind
        _mode = State(initialValue: mode)
        _text = State(initialValue: session.documents[kind] ?? "")
    }

    private var spec: Spec { session.spec }
    private var isApproved: Bool { spec.docs[kind] == .approved }
    private var canApprove: Bool { spec.docs[kind] == .review && assumptions == 0 }
    private var assumptions: Int {
        blocks.count { if case .assumption = $0 { true } else { false } }
    }

    private var next: DocKind? {
        let all = DocKind.allCases
        let index = all.firstIndex(of: kind)! + 1
        return index < all.count ? all[index] : nil
    }

    var body: some View {
        content
            .navigationTitle(kind.fileName)
            .navigationSubtitle(spec.name)
            .toolbar { toolbar }
            .focusedSceneValue(\.approve, approveAction)
            .task(id: text) {
                let parsed = await parseDocument(text, kind: kind)
                blocks = parsed.0
                summary = parsed.1
                if text != session.documents[kind] { session.save(text, for: kind) }   // session debounces the write
            }
            .onChange(of: session.documents[kind]) { _, new in
                if let new, new != text { text = new }
            }
            .onChange(of: spec.stage) { _, stage in
                if stage == .done { showReady = true }
            }
            .alert("Change Assumption", isPresented: Binding(get: { editing != nil }, set: { if !$0 { editing = nil } })) {
                TextField("Assumption", text: $editText)
                Button("Cancel", role: .cancel) {}
                Button("Save") {
                    if let editing { session.changeAssumption(index: editing.index, to: editText, in: kind) }
                }
            } message: {
                Text("Say what should be true instead. The file is updated and the assumption counts as confirmed.")
            }
            .alert("\(kind.fileName) changed in another app", isPresented: Binding(get: { session.conflict == kind }, set: { _ in })) {
                Button("Keep Mine") { session.resolveConflict(keepMine: true) }
                Button("Use File") { session.resolveConflict(keepMine: false) }
            } message: {
                Text("You also have unsaved edits here. Keep Mine replaces the file with your edits. Use File loads the file and drops your edits.")
            }
            .sheet(isPresented: $showReady) {
                SpecReadySheet(session: session)
            }
    }

    private var content: some View {
        Group {
            switch mode {
            case .preview:
                ScrollView {
                    ReviewDocument(
                        kind: kind,
                        blocks: blocks,
                        summary: summary,
                        onConfirm: { session.confirmAssumption(index: $0, in: kind) },
                        onChange: { index, text in
                            editText = text
                            editing = (index, text)
                        }
                    )
                    .frame(maxWidth: 680)
                    .padding(24)
                    .frame(maxWidth: .infinity)
                }
            case .edit:
                TextEditor(text: $text)
                    .font(.body.monospaced())
                    .scrollContentBackground(.hidden)
                    .padding(8)
            }
        }
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .status) {
            VStack(alignment: .leading, spacing: 0) {
                Text("Saved · your edits are never overwritten")
                if let next, !isApproved {
                    Text("Idle · \(next.fileName) starts when you approve")
                        .foregroundStyle(.secondary)
                }
            }
            .font(.caption)
        }
        ToolbarItem {
            Text("\(DocKind.allCases.firstIndex(of: kind)! + 1) of \(DocKind.allCases.count)")
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
        ToolbarItem {
            Picker("Mode", selection: $mode) {
                Text("Preview").tag(Mode.preview)
                Text("Edit Markdown").tag(Mode.edit)
            }
            .pickerStyle(.segmented)
        }
        ToolbarItem {
            ShareLink(item: spec.folder.appending(path: kind.fileName))
        }
        ToolbarItem {
            Button("Show in Finder", systemImage: "folder") { session.showInFinder() }
                .help("Show in Finder")
        }
        ToolbarItem {
            if spec.stage == .done {
                Button("Start Building…") { showReady = true }
                    .buttonStyle(.borderedProminent)
            } else if !isApproved {
                Button("Approve", action: approve)
                    .buttonStyle(.borderedProminent)
                    .disabled(!canApprove)
                    .help(assumptions > 0 ? "Confirm or change each assumption first" : "Approve (⌘↩)")
            }
        }
    }

    private var approveAction: (() -> Void)? {
        guard canApprove else { return nil }
        return { approve() }
    }

    private func approve() {
        Task { await session.approve(kind) }
    }
}

/// The rendered document with the "Before you approve" box.
struct ReviewDocument: View {
    let kind: DocKind
    let blocks: [Block]
    let summary: DocSummary
    var onConfirm: (Int) -> Void = { _ in }
    var onChange: (Int, String) -> Void = { _, _ in }

    private var assumptions: Int {
        blocks.count { if case .assumption = $0 { true } else { false } }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("\(summary.line(for: kind)) Written from \(source) and your answers.")
                .foregroundStyle(.secondary)
            if assumptions > 0 {
                GroupBox {
                    VStack(alignment: .leading, spacing: 4) {
                        Label("Before you approve", systemImage: "checklist")
                            .font(.headline)
                        Text(assumptions == 1 ? "1 assumption to confirm" : "\(assumptions) assumptions to confirm")
                        Text("Confirm or change each assumption to approve.")
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            MarkdownBlocksView(blocks: blocks, onConfirm: onConfirm, onChange: onChange)
        }
    }

    private var source: String {
        let all = DocKind.allCases
        let index = all.firstIndex(of: kind)!
        return index > 0 ? all[index - 1].fileName : "your idea"
    }
}

#Preview("Review") {
    NavigationStack {
        ReviewView(session: PreviewData.session(PreviewData.review), kind: .requirements)
    }
    .environment(PreviewData.appState([PreviewData.review]))
    .frame(width: 1000, height: 720)
}

#Preview("Edit Markdown") {
    NavigationStack {
        ReviewView(session: PreviewData.session(PreviewData.review), kind: .requirements, mode: .edit)
    }
    .environment(PreviewData.appState([PreviewData.review]))
    .frame(width: 1000, height: 720)
}

#Preview("Done") {
    NavigationStack {
        ReviewView(session: PreviewData.session(PreviewData.done), kind: .tasks)
    }
    .environment(PreviewData.appState([PreviewData.done]))
    .frame(width: 1000, height: 720)
}

#Preview("Assumptions to confirm") {
    ScrollView {
        ReviewDocument(kind: .requirements, blocks: PreviewData.requirementsBlocks, summary: DocSummary(stories: 5, criteria: 14, assumptions: 1))
            .padding(24)
    }
    .frame(width: 720, height: 720)
}

#Preview("Ready to approve") {
    ScrollView {
        ReviewDocument(kind: .requirements, blocks: PreviewData.confirmedBlocks, summary: DocSummary(stories: 5, criteria: 14))
            .padding(24)
    }
    .frame(width: 720, height: 720)
}
