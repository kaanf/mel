import SwiftUI
import MelSpec

/// Spec library: each spec shows Discovery and its four files with their status.
struct SidebarView: View {
    @Environment(AppState.self) private var state
    @Binding var selection: SidebarItem?
    let onNewSpec: () -> Void

    var body: some View {
        List(selection: $selection) {
            ForEach(state.specs) { spec in
                Section {
                    Label("Discovery", systemImage: "bubble.left.and.text.bubble.right")
                        .badge(Text(coverage(spec)))
                        .tag(SidebarItem.discovery(spec.id))
                    ForEach(DocKind.allCases, id: \.self) { kind in
                        HStack {
                            Label(kind.fileName, systemImage: "doc.text")
                            Spacer()
                            (spec.docs[kind] ?? .locked).badge
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .tag(SidebarItem.doc(spec.id, kind))
                    }
                } header: {
                    Text(spec.name)
                        .contextMenu {
                            Button("Remove from List") { state.removeFromLibrary(spec.id) }
                        }
                }
            }
        }
        .navigationSplitViewColumnWidth(min: 200, ideal: 240)
        .toolbar {
            ToolbarItem {
                Button("New Spec", systemImage: "plus", action: onNewSpec)
                    .disabled(!state.agent.isReady)
                    .help("New Spec")
            }
        }
    }

    private func coverage(_ spec: Spec) -> String {
        "\(spec.coverage.count { $0.state == .covered }) of \(spec.coverage.count)"
    }
}

#Preview("Specs") {
    @Previewable @State var selection: SidebarItem? = .discovery(PreviewData.discovery.id)
    NavigationSplitView {
        SidebarView(selection: $selection, onNewSpec: {})
    } detail: {
        Text("Detail")
    }
    .environment(PreviewData.appState([PreviewData.discovery, PreviewData.drafting, PreviewData.done]))
    .frame(width: 700, height: 600)
}

#Preview("Empty") {
    @Previewable @State var selection: SidebarItem?
    NavigationSplitView {
        SidebarView(selection: $selection, onNewSpec: {})
    } detail: {
        Text("Detail")
    }
    .environment(PreviewData.appState([]))
    .frame(width: 700, height: 400)
}
