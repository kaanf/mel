import SwiftUI
import MelSpec
import UniformTypeIdentifiers

/// B1 New Spec (design/v2 Native-1-NewSpec): full window, no sidebar. The size comes first; the rest adapts.
struct NewSpecView: View {
    /// What the form starts with (previews and debug screens fill it).
    struct Draft {
        var size: SpecSize?
        var project: Project?
        var name = ""
        var idea = ""
        var happensNow = ""
        var shouldHappen = ""
        var location = ""
        var files: [URL] = []
        var logs: [String] = []
        var buildsOn: Set<String> = []
        var fillGaps = true
    }

    @Environment(AppState.self) private var state
    @Environment(\.openSettings) private var openSettings
    @State private var draft: Draft
    @State private var parent = FileManager.default.homeDirectoryForCurrentUser.appending(path: "Developer", directoryHint: .isDirectory)
    @State private var isAddingFiles = false
    @State private var isChoosingFolder = false
    @State private var isPastingLog = false
    @State private var pastedLog = ""
    @State private var error: String?
    @FocusState private var focus: Field?
    let onAddProject: () -> Void
    let onReadRepo: (Project) -> Void
    let onClose: () -> Void

    private enum Field: Hashable { case name, idea }

    init(draft: Draft = Draft(), onAddProject: @escaping () -> Void, onReadRepo: @escaping (Project) -> Void, onClose: @escaping () -> Void) {
        _draft = State(initialValue: draft)
        self.onAddProject = onAddProject
        self.onReadRepo = onReadRepo
        self.onClose = onClose
    }

    // MARK: Derived

    private var projects: [Project] { state.projects.filter { !$0.isMissing } }
    /// Feature by default; Product when there is no project to work in.
    private var size: SpecSize { draft.size ?? (projects.isEmpty ? .product : .feature) }
    private var project: Project? {
        guard size.needsProject else { return nil }
        return draft.project.flatMap { p in projects.first { $0 == p } } ?? selectedSpecProject ?? projects.first
    }

    private var selectedSpecProject: Project? {
        guard let folder = state.selection.flatMap({ id in state.specs.first { $0.id == id } })?.project else { return nil }
        return projects.first { $0.folder == folder }
    }

    private var context: ProjectContext? { project.flatMap { state.contexts[$0.id] } }
    private var hasContext: Bool { project?.hasContext ?? false }
    private var copy: Copy { Copy(size) }
    private var trimmedIdea: String { draft.idea.trimmingCharacters(in: .whitespacesAndNewlines) }

    /// Start needs an idea; a Quick fix also starts from a log, a file or "Happens now".
    private var hasIdea: Bool {
        !trimmedIdea.isEmpty || (size == .quickFix && (!draft.files.isEmpty || !draft.logs.isEmpty || !draft.happensNow.trimmingCharacters(in: .whitespaces).isEmpty))
    }

    private var canStart: Bool { hasIdea && state.agent.isReady && (project != nil || !size.needsProject) }

    private var name: String {
        let name = draft.name.trimmingCharacters(in: .whitespaces)
        return name.isEmpty ? "Untitled Spec" : name
    }

    /// `<project>/specs/<slug>/`, or `<parent>/<slug>/specs/<slug>/` for a Product without a project.
    private var destination: URL { state.specFolder(name: name, size: size, project: project, parent: parent) }

    /// The folder the spec's root sits in ("Developer"): the project's parent, or the chosen parent.
    private var saveFolderName: String { (project?.folder.deletingLastPathComponent() ?? parent).lastPathComponent }

    // MARK: Body

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Space.x22) {
                header
                sizePicker
                if size.needsProject { projectBox }
                nameField
                ideaBox
                if size == .feature, hasContext, let context { buildsOn(context.modules) }
                if hasIdea { topics } else if size == .product { examples }
                settingsBox
                footer
            }
            .frame(maxWidth: Theme.Size.newSpecWidth)
            .padding(EdgeInsets(top: Theme.Space.x12, leading: Theme.Space.x24, bottom: Theme.Space.x40, trailing: Theme.Space.x24))
            .frame(maxWidth: .infinity)
        }
        .scrollIndicators(.automatic)
        #if DEBUG
        .defaultScrollAnchor(UserDefaults.standard.bool(forKey: "scrollBottom") ? .bottom : .top)   // design comparisons
        #endif
        .setupChrome(barHeight: Theme.Size.toolbar)
        .overlay(alignment: .topTrailing) { settingsButton }
        .background(Theme.Colors.background)
        .background {
            Button("Cancel", action: onClose).keyboardShortcut(.cancelAction).hidden()
        }
        .fileImporter(isPresented: $isAddingFiles, allowedContentTypes: [.item], allowsMultipleSelection: true) { result in
            if case .success(let urls) = result { draft.files += urls.filter { !draft.files.contains($0) } }
        }
        .fileImporter(isPresented: $isChoosingFolder, allowedContentTypes: [.folder]) { result in
            guard case .success(let url) = result else { return }
            if size.needsProject {
                do { draft.project = try state.addProject(url) } catch { self.error = error.localizedDescription }
            } else {
                parent = url
            }
        }
        .sheet(isPresented: $isPastingLog) { pasteLogSheet }
        .alert("Couldn’t Start", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
        } message: {
            Text(error ?? "")
        }
    }

    // MARK: Header

    private var settingsButton: some View {
        Button { openSettings() } label: {
            DesignIcon(glyph: .gear, size: Theme.Size.settingsIcon)
                .foregroundStyle(Theme.Colors.label)
                .frame(width: Theme.Size.toolbarIconButton, height: Theme.Size.buttonToolbar)
                .surface(Theme.Colors.toolbarGlass, .toolbarGroup, in: Capsule())
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Settings")
        .frame(height: Theme.Size.toolbar)
        .padding(.trailing, Theme.Space.x12)
        .ignoresSafeArea(.container, edges: .top)
    }

    private var header: some View {
        HStack(spacing: Theme.Space.x10) {
            Image("Logo")
                .resizable()
                .frame(width: Theme.Size.logoSmall, height: Theme.Size.logoSmall)
                .shadow(Theme.LogoShadow.small)
                .accessibilityHidden(true)
            Text("New Spec")
                .textStyle(Theme.Text.bodyBold)
                .foregroundStyle(Theme.Colors.secondaryLabel)
                .accessibilityAddTraits(.isHeader)
        }
    }

    private func sectionTitle(_ title: String, _ note: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: Theme.Space.x8) {
            Text(title)
                .textStyle(Theme.Text.bodyBold)
                .foregroundStyle(Theme.Colors.label)
            Text(note)
                .textStyle(Theme.Text.caption)
                .foregroundStyle(Theme.Colors.secondaryLabel)
        }
    }

    // MARK: Size

    private var sizePicker: some View {
        VStack(alignment: .leading, spacing: Theme.Space.x8) {
            sectionTitle("What are you making?", "Mel shapes the questions and files to the work")
            HStack(spacing: Theme.Space.x8) {
                ForEach(SpecSize.allCases, id: \.self) { option in
                    sizeCard(option)
                }
            }
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func sizeCard(_ option: SpecSize) -> some View {
        let isSelected = option == size
        let card = Copy(option)
        return Button { draft.size = option } label: {
            VStack(alignment: .leading, spacing: Theme.Space.x3) {
                Text(card.title)
                    .textStyle(Theme.Text.bodyBold)
                    .foregroundStyle(Theme.Colors.label)
                Text(card.note)
                    .textStyle(Theme.Text.caption)
                    .foregroundStyle(Theme.Colors.bodyLabel)
                Text(card.files)
                    .textStyle(Theme.Text.codeMicro)
                    .foregroundStyle(Theme.Colors.secondaryLabel)
            }
            .padding(EdgeInsets(top: Theme.Space.x10, leading: Theme.Space.x12, bottom: Theme.Space.x10, trailing: Theme.Space.x12))
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .surface(isSelected ? Theme.Colors.accentSelectedFill : Theme.Colors.fill, isSelected ? .selected : .outlineLight, in: RoundedRectangle(cornerRadius: Theme.Radius.card))
            .contentShape(RoundedRectangle(cornerRadius: Theme.Radius.card))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    // MARK: Project

    private var projectBox: some View {
        VStack(spacing: 0) {
            HStack(spacing: Theme.Space.x10) {
                DesignIcon(glyph: .folder, size: Theme.Size.folderIcon)
                    .foregroundStyle(Theme.Colors.accent)
                VStack(alignment: .leading, spacing: Theme.Space.x1) {
                    Text("Project")
                        .textStyle(Theme.Text.captionBold)
                        .foregroundStyle(Theme.Colors.secondaryLabel)
                    projectMenu
                    if let project {
                        Text(projectMeta(project))
                            .textStyle(Theme.Text.codeCaption)
                            .foregroundStyle(Theme.Colors.secondaryLabel)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                if project != nil {
                    Text(hasContext ? "Context ready" : "No context yet")
                        .textStyle(Theme.Text.captionMedium)
                        .foregroundStyle(hasContext ? Theme.Colors.successBadgeText : Theme.Colors.warningBadgeText)
                        .padding(.horizontal, Theme.Space.x8)
                        .frame(height: Theme.Size.buttonTiny)
                        .background(hasContext ? Theme.Colors.successBadgeFill : Theme.Colors.warningBadgeFill, in: Capsule())
                }
                Button("Add Project…", action: onAddProject)
                    .buttonStyle(DesignLinkStyle())
            }
            // CSS min-height leaves out the padding.
            .frame(minHeight: Theme.Size.projectRow)
            .padding(EdgeInsets(top: Theme.Space.x8, leading: Theme.Space.x16, bottom: Theme.Space.x8, trailing: Theme.Space.x10))
            if let project, !hasContext {
                HStack(spacing: Theme.Space.x10) {
                    Text("Mel hasn’t read this repo yet. Without project context the agent may rebuild code that already exists.")
                        .textStyle(Theme.Text.callout)
                        .foregroundStyle(Theme.Colors.bodyLabel)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Button("Read Repo (about 1 min)") { onReadRepo(project) }
                        .buttonStyle(DesignButtonStyle(height: Theme.Size.buttonSmall, leading: Theme.Space.x12, trailing: Theme.Space.x12, text: Theme.Text.calloutBold, elevation: .init()))
                }
                .padding(EdgeInsets(top: Theme.Space.x10, leading: Theme.Space.x16, bottom: Theme.Space.x10, trailing: Theme.Space.x16))
                .overlay(alignment: .top) { hairline(Theme.Colors.separatorFaint) }
            }
        }
        .surface(Theme.Colors.fill, .outlineFaint, in: RoundedRectangle(cornerRadius: Theme.Radius.panel))
    }

    private var projectMenu: some View {
        Menu {
            ForEach(projects) { option in
                Button(option.name) { draft.project = option }
            }
        } label: {
            // As WebKit draws the mock's <select>: name 4 pt in, 8 pt arrows 10 pt after it.
            HStack(spacing: Theme.Space.x10) {
                Text(project?.name ?? "No project")
                    .textStyle(Theme.Text.cardTitle)
                    .foregroundStyle(Theme.Colors.label)
                DesignIcon(glyph: .popUp, size: Theme.Size.selectArrowWidth)
                    .foregroundStyle(Theme.Colors.label)
            }
            .padding(.horizontal, Theme.Space.x4)
            .frame(height: Theme.Size.buttonTiny)
            .contentShape(Rectangle())
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .menuIndicator(.hidden)
        .fixedSize()
        .accessibilityLabel("Project")
    }

    /// "~/Developer/yoga-studio-booking · main".
    private func projectMeta(_ project: Project) -> String {
        let path = project.folder.path(percentEncoded: false).abbreviatingHome
        let branch = state.branches[project.id]
        return [String(path.hasSuffix("/") ? path.dropLast() : path[...]), branch].compactMap(\.self).joined(separator: " · ")
    }

    private var popUpArrows: some View {
        DesignIcon(glyph: .popUp, size: Theme.Size.popUpHeight * 10 / 14)
            .foregroundStyle(Theme.Colors.label)
            .frame(width: Theme.Size.popUpWidth, height: Theme.Size.popUpHeight)
    }

    // MARK: Name and idea

    private var nameField: some View {
        VStack(alignment: .leading, spacing: Theme.Space.x2) {
            TextField("Spec name", text: $draft.name, prompt: Text("Untitled Spec").foregroundStyle(Theme.Colors.tertiary))
                .textFieldStyle(.plain)
                // A single-line field ignores `.lineHeight`; centered in the 36 pt line box like CSS.
                .font(Theme.Text.largeTitle.font)
                .tracking(Theme.Text.largeTitle.tracking)
                .frame(height: Theme.Text.largeTitle.lineHeight)
                .foregroundStyle(Theme.Colors.label)
                .focused($focus, equals: .name)
                .focusEffectDisabled()
                .padding(.vertical, Theme.Space.x2)
                .padding(.horizontal, Theme.Space.x8)
                .overlay { focusRing(focus == .name, radius: Theme.Radius.row) }
                .padding(.horizontal, -Theme.Space.x8)
            Text(copy.nameHint)
                .textStyle(Theme.Text.callout)
                .foregroundStyle(Theme.Colors.secondaryLabel)
        }
    }

    private var ideaBox: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(copy.ideaLabel)
                .textStyle(Theme.Text.captionBold)
                .foregroundStyle(Theme.Colors.secondaryLabel)
                .padding(EdgeInsets(top: Theme.Space.x14, leading: Theme.Space.x16, bottom: 0, trailing: Theme.Space.x16))
            IdeaTextArea(text: $draft.idea, label: copy.ideaLabel, placeholder: copy.ideaPlaceholder)
                .focused($focus, equals: .idea)
            if size == .quickFix { bugFields }
            HStack(spacing: Theme.Space.x8) {
                smallButton("Add Files", glyph: .paperclip) { isAddingFiles = true }
                if size == .quickFix {
                    smallButton("Paste Log") { isPastingLog = true }
                }
                Text(copy.dropHint)
                    .textStyle(Theme.Text.caption)
                    .foregroundStyle(Theme.Colors.secondaryLabel)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(EdgeInsets(top: Theme.Space.x8, leading: Theme.Space.x10, bottom: Theme.Space.x10, trailing: Theme.Space.x10))
            .overlay(alignment: .top) { hairline(Theme.Colors.separatorFaint) }
        }
        .surface(Theme.Colors.fill, .outlineFaint, in: RoundedRectangle(cornerRadius: Theme.Radius.panel))
        .overlay { focusRing(focus == .idea, radius: Theme.Radius.panel) }
        .dropDestination(for: URL.self) { urls, _ in
            draft.files += urls.filter { !draft.files.contains($0) }
            return !urls.isEmpty
        }
    }

    private var bugFields: some View {
        VStack(alignment: .leading, spacing: 0) {
            bugRow("Happens now", "What goes wrong?", text: $draft.happensNow)
            bugRow("Should happen", "What should happen instead?", text: $draft.shouldHappen)
            bugRow("Where", "Screen, file or module", text: $draft.location)
            if !evidence.isEmpty {
                FlowLayout(spacing: Theme.Space.x6) {
                    ForEach(evidence) { item in EvidenceChip(name: item.name, kind: item.kind, remove: item.remove) }
                }
                .padding(EdgeInsets(top: Theme.Space.x10, leading: Theme.Space.x16, bottom: Theme.Space.x2, trailing: Theme.Space.x16))
            }
        }
        .overlay(alignment: .top) { hairline(Theme.Colors.separatorFaint) }
    }

    private func bugRow(_ label: String, _ placeholder: String, text: Binding<String>) -> some View {
        HStack(spacing: Theme.Space.x10) {
            Text(label)
                .textStyle(Theme.Text.callout)
                .foregroundStyle(Theme.Colors.secondaryLabel)
                .frame(width: Theme.Size.bugLabelWidth, alignment: .leading)
            TextField(label, text: text, prompt: Text(placeholder).foregroundStyle(Theme.Colors.tertiary))
                .textFieldStyle(.plain)
                .textStyle(Theme.Text.body)
                .foregroundStyle(Theme.Colors.label)
                .frame(height: Theme.Size.button)
        }
        .padding(.horizontal, Theme.Space.x16)
        .frame(minHeight: Theme.Size.bugRow)
        .overlay(alignment: .bottom) { hairline(Theme.Colors.separatorFaint) }
    }

    /// Attached files and pasted logs, as chips.
    private struct Evidence: Identifiable {
        let id: String
        let name: String
        let kind: String
        let remove: () -> Void
    }

    private var evidence: [Evidence] {
        draft.files.map { url in
            Evidence(id: url.absoluteString, name: url.lastPathComponent, kind: Self.kind(of: url)) { draft.files.removeAll { $0 == url } }
        } + draft.logs.enumerated().map { index, _ in
            Evidence(id: "log-\(index)", name: "pasted-\(index + 1).log", kind: "Log") { draft.logs.remove(at: index) }
        }
    }

    static func kind(of url: URL) -> String {
        guard let type = UTType(filenameExtension: url.pathExtension) else { return "File" }
        if type.conforms(to: .movie) { return "Screen recording" }
        if type.conforms(to: .image) { return "Screenshot" }
        if type.conforms(to: .log) || url.pathExtension == "log" { return "Log" }
        return "File"
    }

    private func smallButton(_ title: String, glyph: DesignIcon.Glyph? = nil, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: Theme.Space.x6) {
                if let glyph { DesignIcon(glyph: glyph, size: Theme.Size.paperclipIcon) }
                Text(title).textStyle(Theme.Text.callout)
            }
            .foregroundStyle(Theme.Colors.label)
            .padding(.horizontal, Theme.Space.x10)
            .frame(height: Theme.Size.buttonSmall)
            .surface(Theme.Colors.background, .buttonSmall, in: Capsule())
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private var pasteLogSheet: some View {
        VStack(alignment: .leading, spacing: Theme.Space.x12) {
            Text("Paste Log").textStyle(Theme.Text.sectionTitle)
            TextEditor(text: $pastedLog)
                .font(Theme.Text.codeBlock.font)
                .frame(width: 480, height: 240)
            HStack {
                Spacer()
                Button("Cancel") { pastedLog = ""; isPastingLog = false }
                    .keyboardShortcut(.cancelAction)
                Button("Add Log") {
                    draft.logs.append(pastedLog)
                    pastedLog = ""
                    isPastingLog = false
                }
                .keyboardShortcut(.defaultAction)
                .disabled(pastedLog.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(Theme.Space.x20)
    }

    // MARK: Chips

    private func buildsOn(_ modules: [Module]) -> some View {
        VStack(alignment: .leading, spacing: Theme.Space.x8) {
            sectionTitle("Builds on", "From project context. Agents extend these instead of rebuilding them.")
            FlowLayout(spacing: Theme.Space.x6) {
                ForEach(modules + [Module(name: "Something new", path: "new module")], id: \.name) { module in
                    buildsOnChip(module)
                }
            }
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Builds on")
        }
    }

    private func buildsOnChip(_ module: Module) -> some View {
        let isOn = draft.buildsOn.contains(module.name)
        return Button {
            if isOn { draft.buildsOn.remove(module.name) } else { draft.buildsOn.insert(module.name) }
        } label: {
            HStack(spacing: Theme.Space.x6) {
                Text(module.name).textStyle(Theme.Text.callout)
                Text(module.path)
                    .textStyle(Theme.Text.codeMicro)
                    .foregroundStyle(Theme.Colors.secondaryLabel)
            }
            .foregroundStyle(Theme.Colors.label)
            .padding(.horizontal, Theme.Space.x12)
            .frame(height: Theme.Size.chip)
            .surface(isOn ? Theme.Colors.accentSelectedFill : Theme.Colors.chipFill, isOn ? .selected : .init(), in: Capsule())
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }

    private var topics: some View {
        VStack(alignment: .leading, spacing: Theme.Space.x8) {
            sectionTitle("Mel will ask about", "You can skip any of these")
            FlowLayout(spacing: Theme.Space.x6) {
                ForEach(size.topics, id: \.self) { topic in
                    HStack(spacing: Theme.Space.x6) {
                        Circle()
                            .strokeBorder(Theme.Colors.secondaryLabel, lineWidth: Theme.Size.statusDotStroke)
                            .frame(width: Theme.Size.topicDot, height: Theme.Size.topicDot)
                        Text(topic).textStyle(Theme.Text.callout)
                    }
                    .foregroundStyle(Theme.Colors.label)
                    .padding(.horizontal, Theme.Space.x10)
                    .frame(height: Theme.Size.buttonSmall)
                    .background(Theme.Colors.chipFill, in: Capsule())
                }
            }
        }
    }

    /// B1 and A4x example chips: label and the idea they fill in.
    static let examples = [
        ("Habit tracker for couples", "A habit tracker for couples. Both partners see each other’s streaks and can send a nudge."),
        ("Booking app for a studio", "An app for my yoga studio where members book classes, buy class packs and get reminders."),
        ("Internal tool for a bar", "A back-office app for a bar that shows daily sales and warns when stock runs low."),
    ]

    private var examples: some View {
        VStack(alignment: .leading, spacing: Theme.Space.x8) {
            Text("Or start from an example")
                .textStyle(Theme.Text.bodyBold)
                .foregroundStyle(Theme.Colors.label)
            FlowLayout(spacing: Theme.Space.x6) {
                ForEach(Self.examples, id: \.0) { label, text in
                    Button {
                        draft.name = label
                        draft.idea = text
                    } label: {
                        Text(label)
                            .textStyle(Theme.Text.callout)
                            .foregroundStyle(Theme.Colors.label)
                            .padding(.horizontal, Theme.Space.x12)
                            .frame(height: Theme.Size.buttonSmall)
                            .background(Theme.Colors.chipFill, in: Capsule())
                            .contentShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: Settings

    private var settingsBox: some View {
        VStack(spacing: 0) {
            HStack(spacing: Theme.Space.x10) {
                Text("Agent")
                    .textStyle(Theme.Text.body)
                    .frame(maxWidth: .infinity, alignment: .leading)
                HStack(spacing: Theme.Space.x4) {
                    if state.agent.isReady {
                        DesignIcon(glyph: .check, size: Theme.Size.readyCheck, weight: 2.4)
                            .foregroundStyle(Theme.Colors.success)
                    }
                    Text(state.agent.isReady ? "Ready" : "Not ready")
                        .textStyle(Theme.Text.caption)
                        .foregroundStyle(Theme.Colors.secondaryLabel)
                }
                Menu {
                    Button("Claude Code") {}
                } label: {
                    popUpLabel(spacing: Theme.Space.x8, leading: Theme.Space.x10) { Text("Claude Code") }
                }
                .menuStyle(.button)
                .buttonStyle(.plain)
                .menuIndicator(.hidden)
                .fixedSize()
                .accessibilityLabel("Agent: Claude Code")
            }
            .padding(.leading, Theme.Space.x16)
            .padding(.trailing, Theme.Space.x8)
            .frame(height: Theme.Size.settingsRow)
            hairline(Theme.Colors.separatorLight).padding(.leading, Theme.Space.x16)
            HStack(spacing: Theme.Space.x10) {
                Text("Save to")
                    .textStyle(Theme.Text.body)
                    .fixedSize()
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text(destination.path(percentEncoded: false).abbreviatingHome)
                    .textStyle(Theme.Text.codeCaption)
                    .foregroundStyle(Theme.Colors.secondaryLabel)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .layoutPriority(1)
                Button { isChoosingFolder = true } label: {
                    popUpLabel(spacing: Theme.Space.x6, leading: Theme.Space.x8) {
                        DesignIcon(glyph: .folder, size: Theme.Size.buttonFolderIcon)
                            .foregroundStyle(Theme.Colors.accent)
                        Text(saveFolderName)
                    }
                }
                .buttonStyle(.plain)
                .fixedSize()
                .accessibilityLabel("Choose folder")
            }
            .padding(.leading, Theme.Space.x16)
            .padding(.trailing, Theme.Space.x8)
            .frame(height: Theme.Size.settingsRow)
            hairline(Theme.Colors.separatorLight).padding(.leading, Theme.Space.x16)
            HStack(spacing: Theme.Space.x10) {
                VStack(alignment: .leading, spacing: Theme.Space.x2) {
                    Text("Let Mel fill small gaps")
                        .textStyle(Theme.Text.body)
                    Text("Each one is marked as an assumption for you to confirm.")
                        .textStyle(Theme.Text.caption)
                        .foregroundStyle(Theme.Colors.secondaryLabel)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Toggle("Let Mel fill small gaps", isOn: $draft.fillGaps)
                    .toggleStyle(DesignSwitchStyle())
                    .labelsHidden()
            }
            .frame(minHeight: Theme.Size.projectRow)
            .padding(EdgeInsets(top: Theme.Space.x8, leading: Theme.Space.x16, bottom: Theme.Space.x8, trailing: Theme.Space.x16))
        }
        .foregroundStyle(Theme.Colors.label)
        .background(Theme.Colors.fill, in: RoundedRectangle(cornerRadius: Theme.Radius.panel))
    }

    /// White pop-up button of the settings box (Agent, Save to): content, then the up/down arrows.
    private func popUpLabel(spacing: CGFloat, leading: CGFloat, @ViewBuilder content: () -> some View) -> some View {
        HStack(spacing: spacing) {
            content()
            popUpArrows
        }
        .textStyle(Theme.Text.body)
        .foregroundStyle(Theme.Colors.label)
        .padding(.leading, leading)
        .padding(.trailing, Theme.Space.x6)
        .frame(height: Theme.Size.buttonSmall)
        .surface(Theme.Colors.background, .buttonSmall, in: RoundedRectangle(cornerRadius: Theme.Radius.field))
        .contentShape(RoundedRectangle(cornerRadius: Theme.Radius.field))
    }

    // MARK: Footer

    private var footer: some View {
        HStack(spacing: Theme.Space.x8) {
            Text(hasIdea ? copy.plan : copy.emptyHint)
                .textStyle(Theme.Text.callout)
                .foregroundStyle(Theme.Colors.secondaryLabel)
                .frame(maxWidth: .infinity, alignment: .leading)
            Button("Start", action: start)
                .buttonStyle(DesignButtonStyle(leading: Theme.Space.x20, trailing: Theme.Space.x12, keyHint: "⌘↩", elevation: .primaryLarge))
                .keyboardShortcut(.return, modifiers: .command)
                .disabled(!canStart)
        }
        .padding(.top, Theme.Space.x4)
    }

    private func hairline(_ color: Color) -> some View {
        Rectangle().fill(color).frame(height: Theme.Size.hairline)
    }

    /// Focus ring of the name field and the idea box: 0.5 pt accent line plus a 3 pt 30 % accent glow.
    private func focusRing(_ isFocused: Bool, radius: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: radius)
            .inset(by: -Theme.Space.x2)
            .stroke(Theme.Colors.accentOutline, lineWidth: 3)
            .overlay { RoundedRectangle(cornerRadius: radius).inset(by: -Theme.Size.hairline / 2).stroke(Theme.Colors.accent, lineWidth: Theme.Size.hairline) }
            .opacity(isFocused ? 1 : 0)
            .allowsHitTesting(false)
    }

    // MARK: Start

    /// The idea, plus the Quick fix fields as labeled lines (the session has no separate fields for them).
    private var fullIdea: String {
        guard size == .quickFix else { return trimmedIdea }
        let fields = [("Happens now", draft.happensNow), ("Should happen", draft.shouldHappen), ("Where", draft.location)]
            .map { ($0, $1.trimmingCharacters(in: .whitespaces)) }
            .filter { !$0.1.isEmpty }
            .map { "\($0): \($1)" }
        return ([trimmedIdea].filter { !$0.isEmpty } + fields).joined(separator: "\n\n")
    }

    private func start() {
        guard canStart else { return }
        do {
            let session = try state.createSpec(
                name: name,
                idea: fullIdea,
                size: size,
                project: project,
                parent: parent,
                buildsOn: size == .feature ? Array(draft.buildsOn).sorted() : [],
                fillGaps: draft.fillGaps,
                files: draft.files,
                logs: size == .quickFix ? draft.logs : []
            )
            onClose()
            Task { await session.start() }
        } catch {
            self.error = error.localizedDescription
        }
    }
}

/// The idea text area of B1 and A4x: 15/23 text, 6 lines, placeholder, padding 6/16/12 as drawn.
struct IdeaTextArea: View {
    @Binding var text: String
    let label: String
    let placeholder: String

    /// NSTextView's line fragment padding inside TextEditor.
    private static let inset: CGFloat = 5

    var body: some View {
        // A multi-line TextField ignores line height; TextEditor honors it.
        TextEditor(text: $text)
            .font(Theme.Text.lead.font)
            .lineHeight(.exact(points: Theme.Text.lead.lineHeight!))
            .foregroundStyle(Theme.Colors.label)
            .scrollContentBackground(.hidden)
            .scrollIndicators(.never)
            .focusEffectDisabled()
            .overlay(alignment: .topLeading) {
                if text.isEmpty {
                    Text(placeholder)
                        .font(Theme.Text.lead.font)
                        .lineHeight(.exact(points: Theme.Text.lead.lineHeight!))
                        .foregroundStyle(Theme.Colors.tertiary)
                        .padding(.horizontal, Self.inset)
                        .allowsHitTesting(false)
                }
            }
            // The editor puts a line's extra leading below it; CSS splits it, so move down by half.
            .frame(height: Theme.Text.lead.lineHeight! * CGFloat(Theme.Size.ideaLines) - Theme.Text.lead.glyphShift)
            .padding(EdgeInsets(top: Theme.Space.x6 + Theme.Text.lead.glyphShift, leading: Theme.Space.x16 - Self.inset, bottom: Theme.Space.x12, trailing: Theme.Space.x16 - Self.inset))
            .accessibilityLabel(label)
    }
}

/// An attached file or pasted log (B1): name, kind and a remove button.
struct EvidenceChip: View {
    let name: String
    let kind: String
    let remove: () -> Void

    var body: some View {
        HStack(spacing: Theme.Space.x6) {
            Text(name)
                .textStyle(Theme.Text.codeCaption)
                .foregroundStyle(Theme.Colors.label)
            Text(kind)
                .textStyle(Theme.Text.caption)
                .foregroundStyle(Theme.Colors.secondaryLabel)
            Button(action: remove) {
                DesignIcon(glyph: .close, size: Theme.Size.removeIcon)
                    .foregroundStyle(Theme.Colors.secondaryLabel)
                    .frame(width: Theme.Size.removeButton, height: Theme.Size.removeButton)
                    .background(Theme.Colors.badgeFill, in: Circle())
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Remove \(name)")
        }
        .padding(.leading, Theme.Space.x10)
        .padding(.trailing, Theme.Space.x4)
        .frame(height: Theme.Size.buttonSmall)
        .surface(Theme.Colors.background, .buttonSmallLight, in: Capsule())
    }
}

/// Copy that changes with the size (the mock's `copy`, `hints` and size cards).
private struct Copy {
    let title, note, files, ideaLabel, ideaPlaceholder, nameHint, dropHint, emptyHint, plan: String

    init(_ size: SpecSize) {
        switch size {
        case .quickFix:
            (title, note, files) = ("Quick fix", "A bug or a small change", "SPEC.md")
            (ideaLabel, ideaPlaceholder) = ("What’s wrong? (optional if you attach a log)", "Anything else the agent should know.")
            nameHint = "Taken from the issue or the first line. Click to rename."
            dropHint = "or drop logs, recordings and screenshots"
            emptyHint = "Describe the bug or attach a log to start."
            plan = "1 or 2 questions, then one SPEC.md."
        case .feature:
            (title, note, files) = ("Feature", "One feature in an existing app", "REQUIREMENTS · ARCHITECTURE · TASKS")
            (ideaLabel, ideaPlaceholder) = ("What should it do?", "Describe the change for users. Mel already knows the code.")
            nameHint = "Suggested from the change. Click to rename."
            dropHint = "or drop screenshots, mockups and links here"
            emptyHint = "Describe the change to start."
            plan = "About 3 questions, then 3 files and a final check."
        case .product:
            (title, note, files) = ("Product", "A new app or an area with new screens", "+ PRODUCT · EXPERIENCE")
            (ideaLabel, ideaPlaceholder) = ("Your idea", "What should it do, and who is it for? Plain words are fine.")
            nameHint = "Suggested from your idea. Click to rename."
            dropHint = "or drop screenshots, docs and links here"
            emptyHint = "Describe your idea to start."
            plan = "About 5 questions, then 5 files and a final check."
        }
    }
}

#Preview("Feature") {
    NewSpecView(draft: PreviewData.featureDraft, onAddProject: {}, onReadRepo: { _ in }, onClose: {})
        .environment(PreviewData.newSpecState)
        .frame(width: Theme.Size.windowWidth, height: Theme.Size.windowHeight)
}

#Preview("Feature, no context") {
    NewSpecView(draft: PreviewData.featureDraftNoContext, onAddProject: {}, onReadRepo: { _ in }, onClose: {})
        .environment(PreviewData.newSpecState)
        .frame(width: Theme.Size.windowWidth, height: Theme.Size.windowHeight)
}

#Preview("Quick fix") {
    NewSpecView(draft: PreviewData.quickFixDraft, onAddProject: {}, onReadRepo: { _ in }, onClose: {})
        .environment(PreviewData.newSpecState)
        .frame(width: Theme.Size.windowWidth, height: Theme.Size.windowHeight)
}

#Preview("Product, empty") {
    NewSpecView(draft: NewSpecView.Draft(size: .product), onAddProject: {}, onReadRepo: { _ in }, onClose: {})
        .environment(PreviewData.newSpecState)
        .frame(width: Theme.Size.windowWidth, height: Theme.Size.windowHeight)
}

#Preview("Empty") {
    NewSpecView(onAddProject: {}, onReadRepo: { _ in }, onClose: {})
        .environment(PreviewData.newSpecState)
        .frame(width: Theme.Size.windowWidth, height: Theme.Size.windowHeight)
}
