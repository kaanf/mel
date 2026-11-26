import SwiftUI
import MelSpec

/// Main window: library sidebar, the selected stage and its inspector; B1 New Spec and Lane A take the whole window.
struct MainView: View {
    @Environment(AppState.self) private var state
    @AppStorage("didShowWelcome") private var didShowWelcome = false
    @Binding var isShowingNewSpec: Bool
    @State private var item: SidebarItem?
    @State private var showInspector = true
    /// B1's Add Project… (A2) or Read Repo (A3); back to B1 when done.
    @State private var setupStep: SetupFlow.Step?
    /// C3's start cards open B1 with a size picked.
    @State private var newSpecSize: SpecSize?

    var body: some View {
        #if DEBUG
        // `-screen failure`: C2's dialog in the window, where the design draws it (sheets can't be captured).
        if DebugScreen.current == .failure {
            FailureSheet(session: PreviewData.stoppedSession, kind: .architecture, reason: .usageLimit(resetsAt: nil))
                .padding(.top, 72)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .ignoresSafeArea()
        } else if DebugScreen.current == .settings {
            // `-screen settings`: C4's pane in the window, for comparison with the drawn dialog.
            SettingsView(updates: PreviewData.updates())
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        } else {
            content
        }
        #else
        content
        #endif
    }

    @ViewBuilder
    private var content: some View {
        // One SetupFlow for first run and for B1's Add Project… / Read Repo. `setupStep` latches it, so
        // adding the project (A2 → A3) doesn't swap it for the library before A3 reads the repo.
        if let step = setupStep ?? (needsSetup ? initialSetupStep : nil) {
            SetupFlow(step: step) { newSpec in
                setupStep = nil
                isShowingNewSpec = newSpec
            }
            .onAppear { setupStep = step }
        } else if isShowingNewSpec {
            NewSpecView(draft: initialDraft, onAddProject: { setupStep = .pickProject }, onReadRepo: { setupStep = .projectSetup($0) }) {
                isShowingNewSpec = false
                newSpecSize = nil
            }
        } else {
            library
        }
    }

    private var needsSetup: Bool {
        !didShowWelcome || (state.projects.isEmpty && state.missingFolders.isEmpty)
    }

    private var initialDraft: NewSpecView.Draft {
        #if DEBUG
        if let draft = DebugScreen.current?.newSpecDraft { return draft }
        #endif
        return NewSpecView.Draft(size: newSpecSize)
    }

    private var initialSetupStep: SetupFlow.Step {
        #if DEBUG
        if let step = DebugScreen.current?.setupStep { return step }
        #endif
        return didShowWelcome ? .pickProject : .welcome
    }

    private var library: some View {
        NavigationSplitView {
            SidebarView(selection: $item) { isShowingNewSpec = true }
        } detail: {
            if let item, item.specID.map({ id in state.specs.contains { $0.id == id } }) ?? true {
                detail(item).id(item)
                    .toolbar {
                        if let spec = shownSpec, spec.tokenTotal > 0 {
                            ToolbarItem { TokenReadout(spec: spec) }
                        }
                    }
            } else if state.specs.isEmpty {
                HomeView { size in
                    newSpecSize = size
                    isShowingNewSpec = true
                }
            } else {
                ContentUnavailableView("No Spec Selected", systemImage: "doc.text", description: Text("Choose a spec in the sidebar."))
            }
        }
        .onAppear {
            item = state.selection.flatMap { id in state.specs.first { $0.id == id } }.map(SidebarItem.current)
        }
        .onChange(of: item) { _, item in
            state.selection = item?.specID
        }
        .onChange(of: state.selection) { _, id in
            guard item?.specID != id else { return }
            item = id.flatMap { id in state.specs.first { $0.id == id } }.map(SidebarItem.current)
        }
        // Follow the pipeline (FLOW.md: Approve → B3 drafts the next file): when the shown spec moves on,
        // go with it if its current row was open or an agent run just started.
        .onChange(of: shownSpec.map(SidebarItem.current)) { old, new in
            guard let old, let new, old.specID == new.specID, let item, item.specID == new.specID, let spec = shownSpec else { return }
            if item == old || spec.isRunningStage { self.item = new }
        }
    }

    private var shownSpec: Spec? {
        item?.specID.flatMap { id in state.specs.first { $0.id == id } }
    }

    @ViewBuilder
    private func detail(_ item: SidebarItem) -> some View {
        switch item {
        case .project(let id):
            if let project = state.projects.first(where: { $0.id == id }) {
                ProjectSetupView(project: project, readsOnAppear: false, onChange: { setupStep = .pickProject }, onDone: { isShowingNewSpec = true })
            }
        case .discovery(let id):
            DiscoveryView(session: state.session(for: id), showInspector: $showInspector)
        case .doc(let id, let kind):
            let session = state.session(for: id)
            switch session.spec.docs[kind] ?? .locked {
            case .writing, .stopped:
                DraftingView(session: session, kind: kind, showInspector: $showInspector)
            case .edited:
                RefineView(session: session, kind: kind, showInspector: $showInspector)
            case .review, .approved, .stale:
                ReviewView(session: session, kind: kind)
            case .locked:
                LockedDocView(kind: kind, size: session.spec.size)
            }
        case .analyze(let id):
            let session = state.session(for: id)
            if session.spec.stage == .done {
                SpecReadyView(session: session)
            } else {
                AnalyzeView(session: session)
            }
        }
    }
}

private extension Spec {
    /// A file being written or the analyze run going.
    var isRunningStage: Bool {
        switch stage {
        case .drafting: true
        case .analyze: analyze == .running
        default: false
        }
    }
}

struct LockedDocView: View {
    let kind: DocKind
    let size: SpecSize

    var body: some View {
        ContentUnavailableView {
            Label("\(kind.fileName) Is Locked", systemImage: "lock")
        } description: {
            Text(previous.map { "It starts after you approve \($0.title)." } ?? "It starts after Discovery.")
        }
        .navigationTitle(kind.fileName)
    }

    private var previous: DocKind? {
        let files = size.files
        guard let index = files.firstIndex(of: kind), index > 0 else { return nil }
        return files[index - 1]
    }
}

#Preview("Discovery") {
    @Previewable @State var isShowingNewSpec = false
    MainView(isShowingNewSpec: $isShowingNewSpec)
        .environment(PreviewData.appState([PreviewData.discovery, PreviewData.done]))
        .frame(width: 1100, height: 720)
}

#Preview("Empty library") {
    @Previewable @State var isShowingNewSpec = false
    MainView(isShowingNewSpec: $isShowingNewSpec)
        .environment(PreviewData.appState([]))
        .frame(width: 900, height: 600)
}

#Preview("Locked file") {
    LockedDocView(kind: .architecture, size: .product)
        .frame(width: 600, height: 400)
}
