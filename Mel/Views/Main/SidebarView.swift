import SwiftUI
import MelSpec
import UniformTypeIdentifiers

/// The V2 sidebar (drawn on V2-1, V2-2, V2-3): the project, its specs as Needs you / Building /
/// Done, New and the agent's status. Settings › Specs can list the open spec's files under it (V2-5).
struct SidebarView: View {
    @Environment(AppState.self) private var state
    @Environment(\.openSettings) private var openSettings
    @AppStorage("settingsTab") private var settingsTab = SettingsView.Pane.agents
    @AppStorage("showSidebarFiles") private var showsFiles = false
    @Binding var isShowingNew: Bool
    /// The file open in the board's center.
    @Binding var openFile: BoardFile?
    @FocusState private var isFocused: Bool
    @State private var isAdding = false
    /// A missing project being located.
    @State private var locating: URL?
    @State private var error: String?
    /// The spec being renamed, and the name typed so far.
    @State private var renaming: Spec.ID?
    @State private var newName = ""

    private var project: Project? { state.currentProject }
    private var specs: [Spec] { project.map(state.specs) ?? [] }
    private var selection: Spec.ID? { isShowingNew ? nil : state.selection }

    private static let groups: [(title: String, build: BuildState?, empty: String)] = [
        ("Needs you", nil, "Nothing waiting for you"), ("Building", .building, "Nothing is being built"), ("Done", .done, "Nothing done yet"),
    ]

    var body: some View {
        VStack(spacing: 0) {
            projectButton
                .padding(EdgeInsets(top: Theme.Size.sidebarTop, leading: Theme.Space.x8, bottom: Theme.Space.x8, trailing: Theme.Space.x8))
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Space.x10) {
                    ForEach(Self.groups, id: \.title) { group in
                        let rows = specs.filter { $0.build == group.build }
                        VStack(alignment: .leading, spacing: Theme.Space.x1) {
                            Text(group.title)
                                .textStyle(Theme.Text.captionBold)
                                .foregroundStyle(Theme.Colors.secondaryLabel)
                                .padding(EdgeInsets(top: 0, leading: Theme.Space.x8, bottom: Theme.Space.x2, trailing: Theme.Space.x8))
                                .accessibilityAddTraits(.isHeader)
                            if rows.isEmpty {
                                Text(group.empty)
                                    .textStyle(Theme.Text.callout)
                                    .foregroundStyle(Theme.Colors.emptyGroup)
                                    .padding(.vertical, Theme.Space.x2)
                                    .padding(.horizontal, Theme.Space.x8)
                            }
                            ForEach(rows) { spec in
                                row(spec)
                                if showsFiles, selection == spec.id, spec.stage == .board { files(of: spec) }
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(EdgeInsets(top: Theme.Space.x6, leading: Theme.Space.x8, bottom: Theme.Space.x8, trailing: Theme.Space.x8))
                // A new spec, one moving to Building or Done, the file rows opening under the selected one.
                .animation(.board, value: specs.map { $0.id.uuidString + ($0.build?.rawValue ?? "") })
                .animation(.board, value: selection)
                .animation(.board, value: showsFiles)
            }
            .scrollIndicators(.never)
            footer
        }
        // The design's sidebar is a panel inset 8 pt in a white window, not the system's flush column.
        .frame(width: Theme.Size.boardSidebar)
        .surface(Theme.Colors.sidebarPanel, .sidebar, in: RoundedRectangle(cornerRadius: Theme.Radius.card))
        .padding(EdgeInsets(top: Theme.Space.x8, leading: Theme.Space.x8, bottom: Theme.Space.x8, trailing: 0))
        .background(Theme.Colors.background)
        .ignoresSafeArea(.container, edges: .top)
        .focusable()
        .focusEffectDisabled()
        .focused($isFocused)
        .onKeyPress(.upArrow) { move(by: -1) }
        .onKeyPress(.downArrow) { move(by: 1) }
        .frame(maxWidth: .infinity, alignment: .leading)
        .navigationSplitViewColumnWidth(Theme.Size.boardSidebar + Theme.Space.x8)
        .toolbar(removing: .sidebarToggle)
        .fileImporter(isPresented: Binding(get: { isAdding || locating != nil }, set: { if !$0 { isAdding = false; locating = nil } }), allowedContentTypes: [.folder]) { result in
            guard case .success(let folder) = result else { return }
            do {
                if let missing = locating { try state.locate(missing, at: folder) } else { try state.startProject(folder) }
                state.selection = nil
            } catch {
                self.error = error.localizedDescription
            }
        }
        .alert("Couldn’t Add the Folder", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
        } message: {
            Text(error ?? "")
        }
        .alert("Rename", isPresented: Binding(get: { renaming != nil }, set: { if !$0 { renaming = nil } })) {
            TextField("Name", text: $newName)
            Button("Rename") {
                if let renaming { state.session(for: renaming).setName(newName) }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("The name Mel shows for this spec. Its folder keeps its name.")
        }
    }

    // MARK: Project

    private var projectButton: some View {
        Menu {
            ForEach(state.projects) { other in
                Toggle(other.name, isOn: Binding(get: { other.id == project?.id }, set: { _ in
                    state.projectID = other.id
                    state.selection = nil
                }))
            }
            ForEach(state.missingFolders, id: \.self) { folder in
                Button("Locate \(folder.lastPathComponent)…") { locating = folder }
            }
            Divider()
            Button("Add Project…") { isAdding = true }
            if let project {
                Button("Remove \(project.name) from the List") { state.removeProject(project) }
            }
            ForEach(state.missingFolders, id: \.self) { folder in
                Button("Remove \(folder.lastPathComponent) from the List") { state.removeMissing(folder) }
            }
        } label: {
            HStack(spacing: Theme.Space.x8) {
                Text((project?.name.first.map(String.init) ?? "?").uppercased())
                    .textStyle(Theme.Text.tileLetter)
                    .foregroundStyle(Theme.Colors.projectTileText)
                    .frame(width: Theme.Size.projectTile, height: Theme.Size.projectTile)
                    .background(Theme.Colors.projectTile, in: RoundedRectangle(cornerRadius: Theme.Radius.field))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 0) {
                    Text(project?.name ?? "No project").textStyle(Theme.Text.sidebarProject).lineLimit(1).truncationMode(.tail)
                    Text(projectNote).textStyle(Theme.Text.caption).foregroundStyle(Theme.Colors.secondaryLabel).lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                DesignIcon(glyph: .popUp, size: Theme.Size.popUpHeight, weight: 1.6)
                    .frame(width: Theme.Size.popUpWidth)
                    .foregroundStyle(Theme.Colors.secondaryLabel)
            }
            .foregroundStyle(Theme.Colors.label)
            .padding(.vertical, Theme.Space.x6)
            .padding(.horizontal, Theme.Space.x8)
            .frame(minHeight: Theme.Size.projectButton)
            .surface(Theme.Colors.background, .sidebarButton, in: RoundedRectangle(cornerRadius: Theme.Radius.box))
            .contentShape(RoundedRectangle(cornerRadius: Theme.Radius.box))
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .menuIndicator(.hidden)
        .help(project?.folder.path(percentEncoded: false).abbreviatingHome ?? "")
        .accessibilityLabel("Project: \(project?.name ?? "none"). \(projectNote)")
    }

    private var projectNote: String {
        guard let project else { return "Add or locate a project" }
        if state.readingContext.contains(project.id) { return "Mel is reading this project" }
        if project.hasContext { return "Mel knows this project" }
        return state.contextErrors[project.id] != nil ? "Couldn’t read the project" : "Not read yet"
    }

    // MARK: Specs

    private func row(_ spec: Spec) -> some View {
        let isSelected = selection == spec.id
        return Button {
            select(spec.id)
        } label: {
            HStack(spacing: Theme.Space.x8) {
                spec.sidebarDot
                VStack(alignment: .leading, spacing: 0) {
                    Text(spec.name).textStyle(isSelected ? Theme.Text.bodyMedium : Theme.Text.body).lineLimit(1).truncationMode(.tail)
                    Text(spec.sidebarNote).textStyle(Theme.Text.caption).foregroundStyle(Theme.Colors.secondaryLabel).lineLimit(1)
                        .contentTransition(.opacity)
                        .animation(.board, value: spec.sidebarNote)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .foregroundStyle(Theme.Colors.label)
            .padding(.vertical, Theme.Space.x4)
            .padding(.horizontal, Theme.Space.x8)
            .frame(minHeight: Theme.Size.specRow)
            .background {
                if isSelected { RoundedRectangle(cornerRadius: Theme.Radius.row).fill(Theme.Colors.selectionFill) }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .focusable(false)
        .accessibilityLabel("\(spec.name), \(spec.sidebarNote)")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .transition(.opacity)
        .contextMenu {
            Button("Rename…") {
                newName = spec.name
                renaming = spec.id
            }
            if spec.stage == .done {
                // Mel can't see the coding agent work: the user moves a built spec on.
                if spec.build != .building { Button("Move to Building") { state.session(for: spec.id).setBuild(.building) } }
                if spec.build != .done { Button("Mark as Done") { state.session(for: spec.id).setBuild(.done) } }
                Divider()
            }
            Button("Remove from List") { state.removeFromLibrary(spec.id) }
        }
    }

    /// The open spec's Markdown files (Settings › Specs › Show spec files in the sidebar).
    private func files(of spec: Spec) -> some View {
        VStack(spacing: Theme.Space.x1) {
            ForEach(spec.size.files, id: \.self) { kind in
                fileRow(.doc(kind), state: spec.fileState(kind))
                    .disabled(spec.fileState(kind) == .waiting && spec.halted?.file != kind)   // not started yet
            }
            fileRow(.decisions, state: nil)
        }
        .padding(EdgeInsets(top: Theme.Space.x2, leading: Theme.Space.x22, bottom: Theme.Space.x4, trailing: 0))
        .transition(.drop)
    }

    private func fileRow(_ file: BoardFile, state: FileState?) -> some View {
        Button { openFile = file } label: {
            HStack(spacing: Theme.Space.x6) {
                Text(file.name).textStyle(Theme.Text.codeCaption).lineLimit(1).frame(maxWidth: .infinity, alignment: .leading)
                if let state { FileStateDot(state: state) }
            }
            .foregroundStyle(Theme.Colors.bodyLabel)
            .padding(.horizontal, Theme.Space.x8)
            .frame(height: Theme.Size.sidebarFileRow)
            .background {
                if openFile == file { RoundedRectangle(cornerRadius: Theme.Radius.code).fill(Theme.Colors.selectionFill) }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .focusable(false)
        .accessibilityLabel(state.map { "\(file.name), \($0.word)" } ?? file.name)
        .accessibilityAddTraits(openFile == file ? .isSelected : [])
    }

    private func select(_ id: Spec.ID) {
        state.selection = id
        isShowingNew = false
        isFocused = true
    }

    /// ↑/↓ through the rows as listed.
    private func move(by step: Int) -> KeyPress.Result {
        let order = Self.groups.flatMap { group in specs.filter { $0.build == group.build }.map(\.id) }
        guard !order.isEmpty else { return .ignored }
        let index = selection.flatMap(order.firstIndex).map { min(max($0 + step, 0), order.count - 1) } ?? 0
        select(order[index])
        return .handled
    }

    // MARK: Footer

    private var footer: some View {
        VStack(spacing: Theme.Space.x8) {
            Button { isShowingNew = true } label: {
                HStack(spacing: Theme.Space.x6) {
                    Text("New").textStyle(isShowingNew ? Theme.Text.bodyBold : Theme.Text.bodyMedium)
                    Text("⌘N").textStyle(Theme.Text.caption).foregroundStyle(isShowingNew ? Theme.Colors.likely : Theme.Colors.secondaryLabel)
                }
                .foregroundStyle(isShowingNew ? Theme.Colors.likely : Theme.Colors.label)
                .frame(maxWidth: .infinity)
                .frame(height: Theme.Size.sidebarNew)
                .surface(isShowingNew ? Theme.Colors.newActiveFill : Theme.Colors.background, isShowingNew ? .init() : .sidebarButton, in: RoundedRectangle(cornerRadius: Theme.Radius.row))
                .contentShape(RoundedRectangle(cornerRadius: Theme.Radius.row))
            }
            .buttonStyle(.plain)
            .focusable(false)
            .accessibilityLabel("New")
            Button {
                settingsTab = .agents
                openSettings()
            } label: {
                HStack(spacing: Theme.Space.x6) {
                    Circle().fill(agentColor).frame(width: Theme.Size.topicDot, height: Theme.Size.topicDot)
                    Text(agentLine).textStyle(Theme.Text.caption).foregroundStyle(Theme.Colors.secondaryLabel).frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal, Theme.Space.x4)
                .frame(height: Theme.Size.sidebarAgentLine)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .focusable(false)
            .help("Open Settings › Agents")
        }
        .padding(Theme.Space.x10)
        .overlay(alignment: .top) {
            Rectangle().fill(Theme.Colors.separatorLight).frame(height: Theme.Size.hairline)
        }
    }

    /// The open spec's usage limit shows here too, as drawn on V2-5.
    private var hitLimit: Bool {
        guard state.agent.isReady, let spec = specs.first(where: { $0.id == selection }), case .usageLimit = spec.halted?.reason else { return false }
        return true
    }

    private var agentLine: String { "Claude Code · " + (hitLimit ? "Usage limit" : state.agent.word) }

    private var agentColor: Color {
        if hitLimit { return Theme.Colors.caution }
        switch state.agent {
        case .ready: return Theme.Colors.success
        case .checking: return Theme.Colors.tertiary
        default: return Theme.Colors.caution
        }
    }
}

extension Spec {
    /// The line under a spec's name in the sidebar: what it waits for, or what Mel is doing.
    var sidebarNote: String {
        switch build {
        case .building: return "Building with Claude Code"
        case .done: return "Built"
        case nil: break
        }
        if let halted { return halted.reason == .user ? "Paused" : "Agent stopped" }
        if stage == .discovery {
            let asked = questions.filter { $0.round == .intake }
            guard let open = asked.firstIndex(where: { $0.answer == nil }) else { return "Reading your idea" }
            return "Question \(open + 1) of \(asked.count)"
        }
        if stage == .done || isReady { return "Ready to build" }
        if docs.values.contains(.edited) { return builtOnEdit.isEmpty ? "Edited by you" : "\(builtOnEdit.count) \(builtOnEdit.count == 1 ? "file" : "files") to update" }
        if unplacedChange != nil { return "Rewrite or cancel?" }
        let open = openCards.count
        if open > 0 { return "\(open) \(open == 1 ? "question" : "questions")" }
        if let next = size.files.first(where: { !written.contains($0) }) { return "Writing \(next.fileName)" }
        return analyze == .stale ? "Check didn’t finish" : "Checking the files"
    }

    /// Needs you: blue dot (#C93400 while stopped). Building: blue ring. Done: green dot.
    @ViewBuilder var sidebarDot: some View {
        switch build {
        case .building: StatusDot(style: .ring(Theme.Colors.accent))
        case .done: StatusDot(style: .filled(Theme.Colors.success))
        case nil: StatusDot(style: .filled(halted != nil && halted?.reason != .user ? Theme.Colors.caution : Theme.Colors.accent))
        }
    }
}

#Preview("Needs you, building, done") {
    @Previewable @State var isShowingNew = false
    @Previewable @State var openFile: BoardFile?
    NavigationSplitView {
        SidebarView(isShowingNew: $isShowingNew, openFile: $openFile)
    } detail: {
        Color.white
    }
    .environment(PreviewData.appState(PreviewData.library))
    .frame(width: 900, height: 600)
}

#Preview("New, no specs") {
    @Previewable @State var isShowingNew = true
    @Previewable @State var openFile: BoardFile?
    NavigationSplitView {
        SidebarView(isShowingNew: $isShowingNew, openFile: $openFile)
    } detail: {
        Color.white
    }
    .environment(PreviewData.appState([]))
    .frame(width: 900, height: 600)
}

#Preview("Stopped, usage limit") {
    @Previewable @State var isShowingNew = false
    @Previewable @State var openFile: BoardFile?
    NavigationSplitView {
        SidebarView(isShowingNew: $isShowingNew, openFile: $openFile)
    } detail: {
        Color.white
    }
    .environment(PreviewData.appState([PreviewData.boardStopped]))
    .frame(width: 900, height: 600)
}

#Preview("Missing project") {
    @Previewable @State var isShowingNew = false
    @Previewable @State var openFile: BoardFile?
    NavigationSplitView {
        SidebarView(isShowingNew: $isShowingNew, openFile: $openFile)
    } detail: {
        Color.white
    }
    .environment(PreviewData.appState([], projects: [], missing: [URL(filePath: "/Users/me/Developer/old-portfolio")]))
    .frame(width: 900, height: 600)
}
