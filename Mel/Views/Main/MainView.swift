import SwiftUI
import MelSpec

/// Main window: library sidebar, the selected stage, its inspector, and the New Spec sheet.
struct MainView: View {
    @Environment(AppState.self) private var state
    @Environment(\.openWindow) private var openWindow
    @AppStorage("didShowWelcome") private var didShowWelcome = false
    @Binding var isShowingNewSpec: Bool
    @State private var item: SidebarItem?
    @State private var showInspector = true

    var body: some View {
        NavigationSplitView {
            SidebarView(selection: $item) { isShowingNewSpec = true }
        } detail: {
            if let item, state.specs.contains(where: { $0.id == item.specID }) {
                detail(item).id(item)
            } else if state.specs.isEmpty {
                EmptyLibraryView { isShowingNewSpec = true }
            } else {
                ContentUnavailableView("No Spec Selected", systemImage: "doc.text", description: Text("Choose a spec in the sidebar."))
            }
        }
        .sheet(isPresented: $isShowingNewSpec) {
            NewSpecSheet()
        }
        .onAppear {
            item = state.selection.flatMap { id in state.specs.first { $0.id == id } }.map(SidebarItem.current)
            if !didShowWelcome { openWindow(id: "welcome") }
        }
        .onChange(of: item) { _, item in
            state.selection = item?.specID
        }
        .onChange(of: state.selection) { _, id in
            guard item?.specID != id else { return }
            item = id.flatMap { id in state.specs.first { $0.id == id } }.map(SidebarItem.current)
        }
    }

    @ViewBuilder
    private func detail(_ item: SidebarItem) -> some View {
        let session = state.session(for: item.specID)
        switch item {
        case .discovery:
            DiscoveryView(session: session, showInspector: $showInspector)
        case .doc(_, let kind):
            switch session.spec.docs[kind] ?? .locked {
            case .writing, .stopped:
                DraftingView(session: session, kind: kind, showInspector: $showInspector)
            case .review, .approved, .edited, .stale:
                ReviewView(session: session, kind: kind)
            case .locked:
                LockedDocView(kind: kind)
            }
        }
    }
}

struct EmptyLibraryView: View {
    @Environment(AppState.self) private var state
    let onNewSpec: () -> Void

    var body: some View {
        ContentUnavailableView {
            Label("No Specs Yet", systemImage: "doc.text")
        } description: {
            Text("Start from an idea. The agent turns it into a spec with you.")
        } actions: {
            Button("New Spec…", action: onNewSpec)
                .disabled(!state.agent.isReady)
        }
    }
}

struct LockedDocView: View {
    let kind: DocKind

    var body: some View {
        ContentUnavailableView {
            Label("\(kind.fileName) Is Locked", systemImage: "lock")
        } description: {
            Text(previous.map { "It starts after you approve \($0.title)." } ?? "It starts after Discovery.")
        }
        .navigationTitle(kind.fileName)
    }

    private var previous: DocKind? {
        let all = DocKind.allCases
        let index = all.firstIndex(of: kind)!
        return index > 0 ? all[index - 1] : nil
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
    LockedDocView(kind: .architecture)
        .frame(width: 600, height: 400)
}
