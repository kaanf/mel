import SwiftUI
import MelSpec
import UniformTypeIdentifiers

/// Spec library: each spec shows Discovery and its four files with their status.
struct SidebarView: View {
    @Environment(AppState.self) private var state
    @Binding var selection: SidebarItem?
    let onNewSpec: () -> Void
    @State private var locating: URL?
    @State private var locateError: String?

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
            if !state.missingFolders.isEmpty {
                Section("Missing") {
                    ForEach(state.missingFolders, id: \.self) { folder in
                        missingRow(folder)
                    }
                }
            }
        }
        .fileImporter(isPresented: Binding(get: { locating != nil }, set: { if !$0 { locating = nil } }), allowedContentTypes: [.folder]) { result in
            guard let missing = locating, case .success(let url) = result else { return }
            do { try state.locate(missing, at: url) } catch { locateError = error.localizedDescription }
        }
        .alert("Spec Not Found", isPresented: Binding(get: { locateError != nil }, set: { if !$0 { locateError = nil } })) {
        } message: {
            Text("Choose the project folder or its specs folder. \(locateError ?? "")")
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

    /// A library entry whose folder was moved or deleted (REQ 9.3); titled by the project folder.
    private func missingRow(_ folder: URL) -> some View {
        HStack {
            Label(folder.deletingLastPathComponent().lastPathComponent, systemImage: "questionmark.folder")
                .foregroundStyle(.secondary)
            Spacer()
            Menu {
                Button("Locate…") { locating = folder }
                Button("Remove from List") { state.removeMissing(folder) }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
            .menuStyle(.button)
            .buttonStyle(.borderless)
            .menuIndicator(.hidden)
            .fixedSize()
            .accessibilityLabel("Actions")
        }
        .help("Moved or deleted: \(folder.path(percentEncoded: false))")
        .contextMenu {
            Button("Locate…") { locating = folder }
            Button("Remove from List") { state.removeMissing(folder) }
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

#Preview("Missing folder") {
    @Previewable @State var selection: SidebarItem?
    NavigationSplitView {
        SidebarView(selection: $selection, onNewSpec: {})
    } detail: {
        Text("Detail")
    }
    .environment(PreviewData.appState([PreviewData.done], missing: [URL(filePath: "/Users/me/Developer/old-recipes/specs")]))
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
