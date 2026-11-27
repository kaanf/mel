import SwiftUI
import MelSpec

/// Main window (FLOW.md › V2): Start until there is a project, then the sidebar with New, the
/// selected spec's Board, or Ready once it is handed off.
struct MainView: View {
    @Environment(AppState.self) private var state
    @Environment(\.controlActiveState) private var activeState
    @AppStorage("didShowWelcome") private var didShowWelcome = false
    @AppStorage("showTokens") private var showsTokens = true
    @Binding var isShowingNew: Bool
    /// Start with "No code yet": New has no project until the first spec makes its folder.
    @State private var startsFromIdea = false
    /// The file open in the board's center; the sidebar's file rows set it too.
    @State private var openFile: BoardFile?

    var body: some View {
        content
            // "Mel looks again when you come back to this window."
            .onChange(of: activeState) { _, active in
                if active == .key, !state.agent.isReady, state.agent != .checking { Task { await state.scanForAgent() } }
            }
    }

    @ViewBuilder
    private var content: some View {
        #if DEBUG
        // `-screen settings` / `specsSettings`: a pane in the window, for comparison with the drawn dialog.
        if DebugScreen.current == .settings {
            AgentSettings().frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        } else if DebugScreen.current == .specsSettings {
            SpecsSettings().frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top).background(Theme.Colors.settingsBackground)
        } else {
            flow
        }
        #else
        flow
        #endif
    }

    @ViewBuilder
    private var flow: some View {
        // A library with only missing folders starts over too; the sidebar's project menu offers Locate once a project is there.
        if state.projects.isEmpty {
            if startsFromIdea, hasStarted {
                NewView { isShowingNew = false }
            } else {
                start
            }
        } else if !hasStarted {
            start
        } else {
            library
        }
    }

    private var hasStarted: Bool {
        #if DEBUG
        if DebugScreen.current != nil { return true }   // fixtures open on their screen
        #endif
        return didShowWelcome
    }

    private var start: some View {
        StartView { fromIdea in
            didShowWelcome = true
            startsFromIdea = fromIdea
            isShowingNew = true
        }
    }

    private var library: some View {
        NavigationSplitView {
            SidebarView(isShowingNew: $isShowingNew, openFile: $openFile)
        } detail: {
            ZStack {
                if !isShowingNew, let spec = shownSpec {
                    detail(spec).id(spec.id).transition(.opacity)
                } else {
                    NewView(idea: initialIdea) { isShowingNew = false }.id(state.currentProject?.id).transition(.opacity)
                }
            }
            // New ↔ a spec, one spec ↔ another, Board → Ready: a short cross-fade instead of a cut.
            .animation(.easeInOut(duration: 0.18), value: isShowingNew)
            .animation(.easeInOut(duration: 0.18), value: shownSpec?.id)
            .animation(.board, value: shownSpec?.stage)
        }
        // Full screen draws the toolbar as its own band with a line under it; the window doesn't.
        .toolbarBackgroundVisibility(.hidden, for: .windowToolbar)
        .onChange(of: state.selection) { _, id in
            openFile = nil
            if id != nil { isShowingNew = false }
        }
    }

    /// The selected spec, when it belongs to the project the sidebar shows.
    private var shownSpec: Spec? {
        guard let project = state.currentProject else { return nil }
        return state.specs.first { $0.id == state.selection && $0.project == project.folder }
    }

    @ViewBuilder
    private func detail(_ spec: Spec) -> some View {
        let session = state.session(for: spec.id)
        if spec.stage == .done {
            BuildView(session: session)
        } else {
            BoardView(session: session, openFile: $openFile)
                .toolbar {
                    if showsTokens, spec.tokenTotal > 0 {
                        ToolbarItem { TokenReadout(spec: spec) }
                    }
                }
        }
    }

    private var initialIdea: String {
        #if DEBUG
        if DebugScreen.current == .new { return PreviewData.featureIdea }
        #endif
        return ""
    }
}

#Preview("Board") {
    @Previewable @State var isShowingNew = false
    MainView(isShowingNew: $isShowingNew)
        .environment(PreviewData.appState(PreviewData.library, sessions: [PreviewData.boardSession]))
        .defaultAppStorage(PreviewData.startedDefaults)
        .frame(width: Theme.Size.windowWidth, height: Theme.Size.windowHeight)
}

#Preview("New, no specs") {
    @Previewable @State var isShowingNew = true
    MainView(isShowingNew: $isShowingNew)
        .environment(PreviewData.appState([]))
        .defaultAppStorage(PreviewData.startedDefaults)
        .frame(width: Theme.Size.windowWidth, height: Theme.Size.windowHeight)
}

#Preview("First launch") {
    @Previewable @State var isShowingNew = false
    MainView(isShowingNew: $isShowingNew)
        .environment(PreviewData.appState([], projects: [], foundRepositories: PreviewData.repositories))
        .frame(width: Theme.Size.windowWidth, height: Theme.Size.windowHeight)
}
