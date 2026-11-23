import SwiftUI
import MelSpec

/// Library sidebar, design/v2 variant drawn on B5–C3: per project a Project context row,
/// "Specs", and each spec with Discovery, its size's files and Analyze. Rows are drawn here
/// (not a List) to match the design's selection; ↑/↓ move the selection.
struct SidebarView: View {
    @Environment(AppState.self) private var state
    @Binding var selection: SidebarItem?
    let onNewSpec: () -> Void
    @State private var collapsed: Set<Spec.ID> = []
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(state.projects) { project in
                        projectSection(project)
                    }
                }
                .padding(.top, Theme.Size.titleBar)
            }
            .scrollIndicators(.never)
            footer
        }
        // The design's sidebar is a panel inset 8 pt in a white window, not the system's flush column.
        .frame(width: Theme.Size.sidebarWidth)
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
        .navigationSplitViewColumnWidth(Theme.Size.sidebarWidth + Theme.Space.x8)
        .toolbar(removing: .sidebarToggle)
    }

    // MARK: Sections

    @ViewBuilder
    private func projectSection(_ project: Project) -> some View {
        let specs = state.specs(in: project)
        SidebarRow(
            item: .project(project.id), selection: $selection, isFocused: $isFocused,
            label: project.name, status: (project.isMissing ? "Missing" : project.hasContext ? "Ready" : "No context", nil), leading: Theme.Space.x8
        ) {
            DesignIcon(glyph: .house, size: Theme.Size.projectIcon)
                .foregroundStyle(Theme.Colors.secondaryLabel)
        }
        .padding(.horizontal, Theme.Space.x8)
        .padding(.bottom, Theme.Space.x6)
        .help(project.folder.path(percentEncoded: false))
        .contextMenu {
            Button("Remove from List") { state.removeProject(project) }
        }

        Text("Specs")
            .textStyle(Theme.Text.captionBold)
            .foregroundStyle(Theme.Colors.secondaryLabel)
            .padding(EdgeInsets(top: Theme.Space.x4, leading: Theme.Space.x18, bottom: Theme.Space.x4, trailing: Theme.Space.x18))

        if specs.isEmpty {
            emptySpecs
        } else {
            VStack(alignment: .leading, spacing: Theme.Space.x1) {
                ForEach(specs) { spec in
                    specHeader(spec)
                    if !collapsed.contains(spec.id) {
                        ForEach(rows(of: spec), id: \.item) { row in
                            SidebarRow(item: row.item, selection: $selection, isFocused: $isFocused, label: row.name, status: (row.word, row.dot), leading: Theme.Space.x26) {
                                EmptyView()
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, Theme.Space.x8)
        }
    }

    private func specHeader(_ spec: Spec) -> some View {
        Button {
            withAnimation(.snappy(duration: 0.2)) {
                if collapsed.contains(spec.id) { collapsed.remove(spec.id) } else { collapsed.insert(spec.id) }
            }
        } label: {
            HStack(spacing: Theme.Space.x6) {
                DesignIcon(glyph: .chevronDown, size: Theme.Size.chevron)
                    .rotationEffect(.degrees(collapsed.contains(spec.id) ? -90 : 0))
                    .foregroundStyle(Theme.Colors.secondaryLabel)
                Text(spec.name)
                    .textStyle(Theme.Text.body)
                    .foregroundStyle(Theme.Colors.label)
                    .lineLimit(1)
                Spacer(minLength: 0)
            }
            .padding(.leading, Theme.Space.x4)
            .padding(.trailing, Theme.Space.x8)
            .frame(height: Theme.Size.sidebarRow)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .focusable(false)
        .accessibilityLabel(spec.name)
        .accessibilityValue(collapsed.contains(spec.id) ? "Collapsed" : "Expanded")
        .contextMenu {
            Button("Remove from List") { state.removeFromLibrary(spec.id) }
        }
    }

    /// C3: a project without specs.
    private var emptySpecs: some View {
        VStack(alignment: .leading, spacing: Theme.Space.x6) {
            Text("No specs yet. Each spec you start shows up here with its files.")
                .textStyle(Theme.Text.callout)
                .foregroundStyle(Theme.Colors.secondaryLabel)
            VStack(alignment: .leading, spacing: Theme.Space.x6) {
                placeholderBar(width: 0.7, fill: Theme.Colors.selectionFill)
                placeholderBar(width: 0.55, fill: Theme.Colors.badgeFill).padding(.leading, Theme.Space.x14)
                placeholderBar(width: 0.6, fill: Theme.Colors.badgeFill).padding(.leading, Theme.Space.x14)
            }
            .padding(.top, Theme.Space.x6)
            .opacity(0.5)
            .accessibilityHidden(true)
        }
        .padding(EdgeInsets(top: Theme.Space.x6, leading: Theme.Space.x18, bottom: Theme.Space.x6, trailing: Theme.Space.x18))
    }

    private func placeholderBar(width: CGFloat, fill: Color) -> some View {
        GeometryReader { proxy in
            RoundedRectangle(cornerRadius: Theme.Radius.keyHint).fill(fill)
                .frame(width: proxy.size.width * width)
        }
        .frame(height: Theme.Size.statusDot)
    }

    private var footer: some View {
        HStack {
            Button(action: onNewSpec) {
                HStack(spacing: Theme.Space.x6) {
                    DesignIcon(glyph: .plus, size: Theme.Size.plusIcon)
                    Text("New Spec").textStyle(Theme.Text.body)
                }
                .foregroundStyle(Theme.Colors.secondaryLabel)
                .padding(.horizontal, Theme.Space.x6)
                .frame(height: Theme.Size.buttonMini)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(!state.agent.isReady)
            Spacer(minLength: 0)
        }
        .padding(EdgeInsets(top: Theme.Space.x10, leading: Theme.Space.x12, bottom: Theme.Space.x10, trailing: Theme.Space.x12))
        .overlay(alignment: .top) {
            Rectangle().fill(Theme.Colors.separatorLight).frame(height: Theme.Size.hairline)
        }
    }

    // MARK: Rows and statuses

    struct Row {
        let item: SidebarItem
        let name: String
        let word: String
        let dot: StatusDot.Style
    }

    private func rows(of spec: Spec) -> [Row] {
        var rows = [Row(item: .discovery(spec.id), name: "Discovery", word: coverage(spec), dot: spec.stage == .discovery ? .ring(Theme.Colors.label) : .filled(Theme.Colors.success))]
        for kind in spec.size.files {
            let (word, dot) = Self.status(spec.docs[kind] ?? .locked, intake: spec.stage == .discovery)
            rows.append(Row(item: .doc(spec.id, kind), name: kind.fileName, word: word, dot: dot))
        }
        if spec.size.hasAnalyze {
            let (word, dot) = Self.status(spec.analyze, intake: spec.stage == .discovery)
            rows.append(Row(item: .analyze(spec.id), name: "Analyze", word: word, dot: dot))
        }
        return rows
    }

    /// Word and dot per file status (V2 §7). Drawn in the design: Approved, Review, Edited, Locked,
    /// Out of date. Not drawn, same scheme: Drafting (B3's purple), Stopped (#C93400), Queued (Locked dot).
    static func status(_ status: DocStatus, intake: Bool) -> (String, StatusDot.Style) {
        switch status {
        case .locked: (intake ? "Queued" : "Locked", .dashed)
        case .writing: ("Drafting", .running)
        case .stopped: ("Stopped", .filled(Theme.Colors.caution))
        case .review: ("Review", .ring(Theme.Colors.label))
        case .approved: ("Approved", .filled(Theme.Colors.success))
        case .edited: ("Edited", .ring(Theme.Colors.label))
        case .stale: ("Out of date", .filled(Theme.Colors.warning))
        }
    }

    /// Analyze row: Queued / Locked / Running / n issues / Passed / Rerun.
    static func status(_ status: AnalyzeStatus, intake: Bool) -> (String, StatusDot.Style) {
        switch status {
        case .locked: (intake ? "Queued" : "Locked", .dashed)
        case .running: ("Running", .running)
        case .issues(let count): (count == 1 ? "1 issue" : "\(count) issues", .filled(Theme.Colors.caution))
        case .passed: ("Passed", .filled(Theme.Colors.success))
        case .stale: ("Rerun", .filled(Theme.Colors.warning))
        }
    }

    private func coverage(_ spec: Spec) -> String {
        "\(spec.coverage.count { $0.state == .covered }) of \(spec.coverage.count)"
    }

    /// Visible rows in order, for ↑/↓.
    private var order: [SidebarItem] {
        state.projects.flatMap { project in
            [SidebarItem.project(project.id)] + state.specs(in: project).flatMap { spec in
                collapsed.contains(spec.id) ? [] : rows(of: spec).map(\.item)
            }
        }
    }

    private func move(by step: Int) -> KeyPress.Result {
        let order = order
        guard !order.isEmpty else { return .ignored }
        guard let current = selection, let index = order.firstIndex(of: current) else {
            selection = order.first
            return .handled
        }
        selection = order[min(max(index + step, 0), order.count - 1)]
        return .handled
    }
}

/// One selectable sidebar row: 28 pt, name, optional dot and status word (design/v2 `rowBase`).
private struct SidebarRow<Icon: View>: View {
    let item: SidebarItem
    @Binding var selection: SidebarItem?
    var isFocused: FocusState<Bool>.Binding
    let label: String
    let status: (word: String, dot: StatusDot.Style?)?
    /// Leading padding inside the row: 8 for Project context, 26 for a spec's files.
    let leading: CGFloat
    @ViewBuilder let icon: Icon

    private var isSelected: Bool { selection == item }

    var body: some View {
        Button {
            selection = item
            isFocused.wrappedValue = true
        } label: {
            HStack(spacing: Theme.Space.x6) {
                icon
                Text(label)
                    .textStyle(isSelected ? Theme.Text.bodyMedium : Theme.Text.body)
                    .foregroundStyle(Theme.Colors.label)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if let status {
                    if let dot = status.dot { StatusDot(style: dot) }
                    Text(status.word)
                        .textStyle(isSelected ? Theme.Text.captionMedium : Theme.Text.caption)
                        .foregroundStyle(Theme.Colors.secondaryLabel)
                        .fixedSize()
                }
            }
            .padding(.leading, leading)
            .padding(.trailing, Theme.Space.x8)
            .frame(height: Theme.Size.sidebarRow)
            .background {
                if isSelected {
                    RoundedRectangle(cornerRadius: Theme.Radius.row).fill(Theme.Colors.selectionFill)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .focusable(false)
        .accessibilityLabel(status.map { "\(label), \($0.word)" } ?? label)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

#Preview("Spec in review") {
    @Previewable @State var selection: SidebarItem? = .doc(PreviewData.review.id, .requirements)
    NavigationSplitView {
        SidebarView(selection: $selection, onNewSpec: {})
    } detail: {
        Color.white
    }
    .environment(PreviewData.appState([PreviewData.review]))
    .frame(width: 900, height: 600)
}

#Preview("Intake") {
    @Previewable @State var selection: SidebarItem? = .discovery(PreviewData.discovery.id)
    NavigationSplitView {
        SidebarView(selection: $selection, onNewSpec: {})
    } detail: {
        Color.white
    }
    .environment(PreviewData.appState([PreviewData.discovery]))
    .frame(width: 900, height: 600)
}

#Preview("Drafting") {
    @Previewable @State var selection: SidebarItem? = .doc(PreviewData.drafting.id, .requirements)
    NavigationSplitView {
        SidebarView(selection: $selection, onNewSpec: {})
    } detail: {
        Color.white
    }
    .environment(PreviewData.appState([PreviewData.drafting]))
    .frame(width: 900, height: 600)
}

#Preview("Edited, out of date") {
    @Previewable @State var selection: SidebarItem? = .doc(PreviewData.edited.id, .requirements)
    NavigationSplitView {
        SidebarView(selection: $selection, onNewSpec: {})
    } detail: {
        Color.white
    }
    .environment(PreviewData.appState([PreviewData.edited]))
    .frame(width: 900, height: 600)
}

#Preview("Analyze issues") {
    @Previewable @State var selection: SidebarItem? = .analyze(PreviewData.analyzeIssues.id)
    NavigationSplitView {
        SidebarView(selection: $selection, onNewSpec: {})
    } detail: {
        Color.white
    }
    .environment(PreviewData.appState([PreviewData.analyzeIssues]))
    .frame(width: 900, height: 600)
}

#Preview("Stopped") {
    @Previewable @State var selection: SidebarItem? = .doc(PreviewData.usageLimit.id, .architecture)
    NavigationSplitView {
        SidebarView(selection: $selection, onNewSpec: {})
    } detail: {
        Color.white
    }
    .environment(PreviewData.appState([PreviewData.usageLimit]))
    .frame(width: 900, height: 600)
}

#Preview("No specs") {
    @Previewable @State var selection: SidebarItem?
    NavigationSplitView {
        SidebarView(selection: $selection, onNewSpec: {})
    } detail: {
        Color.white
    }
    .environment(PreviewData.appState([]))
    .frame(width: 900, height: 600)
}
