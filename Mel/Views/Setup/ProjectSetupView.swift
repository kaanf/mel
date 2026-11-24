import SwiftUI
import MelSpec

/// A3 Project context (design/v2 Native-0b-ProjectSetup): Mel reads the repo once and writes `.mel/project/`.
struct ProjectSetupView: View {
    @Environment(AppState.self) private var state
    let project: Project
    @State var isNewProject: Bool
    @State private var isAddingRule = false
    @State private var rule = ""
    @State private var error: String?
    /// Lane A reads the repo on appear; the sidebar's project row waits for Read Repo.
    let readsOnAppear: Bool
    let onChange: () -> Void
    let onDone: () -> Void

    init(project: Project, isNewProject: Bool = false, readsOnAppear: Bool = true, onChange: @escaping () -> Void, onDone: @escaping () -> Void) {
        self.project = project
        _isNewProject = State(initialValue: isNewProject)
        self.readsOnAppear = readsOnAppear
        self.onChange = onChange
        self.onDone = onDone
    }

    /// This project's run, or (opened from the sidebar) its saved context, so it isn't read again.
    private var setup: ProjectSetup? {
        if let setup = state.projectSetup, setup.project == project { return setup }
        guard let context = state.contexts[project.id] else { return nil }
        return ProjectSetup(project: project, isNewProject: false, isRunning: false, activity: [], context: context, lastError: nil, branch: state.branches[project.id])
    }
    private var isRunning: Bool { setup?.isRunning ?? readsOnAppear }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Space.x22) {
                VStack(alignment: .leading, spacing: Theme.Space.x6) {
                    Text("Once per project")
                        .textStyle(Theme.Text.captionBold)
                        .foregroundStyle(Theme.Colors.secondaryLabel)
                    Text("Let Mel learn your project")
                        .textStyle(Theme.Text.title1)
                        .foregroundStyle(Theme.Colors.label)
                        .accessibilityAddTraits(.isHeader)
                    Text("Mel reads the repo once and writes four short context files. Every spec and every agent reads them first, so new work extends your code instead of rebuilding it.")
                        .textStyle(Theme.Text.intro)
                        .foregroundStyle(Theme.Colors.bodyLabel)
                        .frame(maxWidth: Theme.Size.projectSetupTextWidth, alignment: .leading)
                }
                folderBox
                if !isNewProject { readList }
                contextFiles
                principlesCard
                footer
            }
            .frame(maxWidth: Theme.Size.projectSetupWidth)
            .padding(EdgeInsets(top: Theme.Space.x16, leading: Theme.Space.x32, bottom: Theme.Space.x32, trailing: Theme.Space.x32))
            .frame(maxWidth: .infinity)
        }
        .scrollIndicators(.automatic)
        .setupChrome(title: "Set Up Project")
        .alert("Add Rule", isPresented: $isAddingRule) {
            TextField("Rule", text: $rule)
            Button("Add") { addRule() }.disabled(rule.trimmingCharacters(in: .whitespaces).isEmpty)
            Button("Cancel", role: .cancel) { rule = "" }
        } message: {
            Text("Every spec and agent must follow it. Mel adds it to principles.md.")
        }
        .alert("Couldn’t Save", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
        } message: {
            Text(error ?? "")
        }
        .task(id: project) {
            if setup == nil, readsOnAppear { await state.setUpProject(project) }
        }
    }

    // MARK: Folder

    private var folderBox: some View {
        VStack(spacing: 0) {
            HStack(spacing: Theme.Space.x10) {
                DesignIcon(glyph: .folder, size: Theme.Size.folderIcon)
                    .foregroundStyle(Theme.Colors.accent)
                VStack(alignment: .leading, spacing: 0) {
                    Text(project.name)
                        .textStyle(Theme.Text.bodyBold)
                        .foregroundStyle(Theme.Colors.label)
                    Text(folderLine)
                        .textStyle(Theme.Text.codeCaption)
                        .foregroundStyle(Theme.Colors.secondaryLabel)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Button("Change…", action: onChange)
                    .buttonStyle(DesignButtonStyle(role: .secondary, height: Theme.Size.buttonSmall, leading: Theme.Space.x12, trailing: Theme.Space.x12, text: Theme.Text.callout, elevation: .buttonSmall))
            }
            .padding(.leading, Theme.Space.x16)
            .padding(.trailing, Theme.Space.x8)
            .frame(height: Theme.Size.folderRow)
            Rectangle().fill(Theme.Colors.separatorLight).frame(height: Theme.Size.hairline).padding(.leading, Theme.Space.x16)
            HStack(spacing: Theme.Space.x12) {
                Text("What is in this folder?")
                    .textStyle(Theme.Text.body)
                    .foregroundStyle(Theme.Colors.label)
                    .frame(maxWidth: .infinity, alignment: .leading)
                SegmentedPicker(selection: $isNewProject, options: [(false, "Existing code"), (true, "New project, no code yet")])
            }
            .padding(EdgeInsets(top: Theme.Space.x10, leading: Theme.Space.x16, bottom: Theme.Space.x12, trailing: Theme.Space.x16))
        }
        .background(Theme.Colors.fill, in: RoundedRectangle(cornerRadius: Theme.Radius.panel))
    }

    /// "~/Developer/yoga-studio-booking · main · 214 files"
    private var folderLine: String {
        [project.folder.path(percentEncoded: false).abbreviatingHome.trimmingSuffix("/"), setup?.branch, setup?.fileCount.map { "\($0) files" }]
            .compactMap(\.self).joined(separator: " · ")
    }

    // MARK: What Mel read

    private var readList: some View {
        VStack(alignment: .leading, spacing: Theme.Space.x8) {
            Text("What Mel read")
                .textStyle(Theme.Text.bodyBold)
                .foregroundStyle(Theme.Colors.label)
                .padding(.horizontal, Theme.Space.x4)
            VStack(spacing: 0) {
                if setup == nil, !readsOnAppear {
                    actionRow("Mel hasn’t read this repo yet.", glyph: .doc, action: "Read Repo (about 1 min)")
                } else if let message = setup?.lastError {
                    actionRow(message, glyph: .alert, action: "Try Again")
                } else if let read = setup?.context?.read, !read.isEmpty {
                    ForEach(read, id: \.self) { item in
                        readRow(item.label, source: item.source, done: true)
                    }
                } else {
                    // While reading: the run's activity, the last line still going.
                    let lines = setup?.activity ?? []
                    ForEach(lines) { line in
                        readRow(line.text, source: nil, done: !isRunning || line.id != lines.last?.id)
                    }
                }
            }
            .padding(.vertical, Theme.Space.x4)
            .background(Theme.Colors.fill, in: RoundedRectangle(cornerRadius: Theme.Radius.card))
        }
    }

    /// Not read yet, or the run failed: one line and a link that starts the run.
    private func actionRow(_ message: String, glyph: DesignIcon.Glyph, action: String) -> some View {
        HStack(spacing: Theme.Space.x10) {
            DesignIcon(glyph: glyph, size: Theme.Size.smallCheck)
                .foregroundStyle(glyph == .alert ? Theme.Colors.warning : Theme.Colors.secondaryLabel)
            Text(message)
                .textStyle(Theme.Text.body)
                .foregroundStyle(Theme.Colors.label)
                .frame(maxWidth: .infinity, alignment: .leading)
            Button(action) { Task { await state.setUpProject(project) } }
                .disabled(state.isAgentBusy)
                .buttonStyle(DesignLinkStyle())
        }
        .padding(.horizontal, Theme.Space.x14)
        .frame(minHeight: Theme.Size.chip)
    }

    private func readRow(_ label: String, source: String?, done: Bool) -> some View {
        HStack(spacing: Theme.Space.x10) {
            if done {
                DesignIcon(glyph: .check, size: Theme.Size.smallCheck, weight: 2.2)
                    .foregroundStyle(Theme.Colors.success)
            } else {
                StatusDot(style: .running).frame(width: Theme.Size.smallCheck)
            }
            Text(label)
                .textStyle(Theme.Text.body)
                .foregroundStyle(Theme.Colors.label)
                .frame(maxWidth: .infinity, alignment: .leading)
            if let source {
                Text(source)
                    .textStyle(Theme.Text.codeCaption)
                    .foregroundStyle(Theme.Colors.secondaryLabel)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, Theme.Space.x14)
        .frame(minHeight: Theme.Size.chip)
        .accessibilityElement(children: .combine)
    }

    // MARK: Project context

    private struct ContextFile: Identifiable {
        let name: String
        let state: String
        let about: String
        let sample: String?
        var id: String { name }
    }

    private var files: [ContextFile] {
        let context = setup?.context
        if isNewProject {
            return [
                ContextFile(name: "product.md", state: "Empty", about: "What the app is for, who uses it, what must not break.", sample: "Filled from your first spec’s PRODUCT.md."),
                ContextFile(name: "tech.md", state: "Choose", about: "Stack, libraries and tools the agents must prefer.", sample: "Pick a starting stack or let ARCHITECTURE.md decide it."),
                ContextFile(name: "structure.md", state: "Empty", about: "Where code goes and how it is named.", sample: "Written after the first tasks create the folders."),
            ]
        }
        return [
            ContextFile(name: "product.md", state: state("product.md"), about: "What the app is for, who uses it, what must not break.", sample: context.flatMap { Self.firstParagraph($0.product) }),
            ContextFile(name: "tech.md", state: state("tech.md"), about: "Stack, libraries and tools the agents must prefer.", sample: context.flatMap { Self.firstParagraph($0.tech) }),
            ContextFile(name: "structure.md", state: state("structure.md"), about: "Where code goes and how it is named.", sample: context.flatMap { Self.firstParagraph($0.structure) }),
        ]
    }

    /// The card's state word from the run ("From README", "Detected").
    private func state(_ file: String) -> String {
        setup?.context?.sources[file] ?? (isRunning ? "Reading" : "Detected")
    }

    private var contextFiles: some View {
        VStack(alignment: .leading, spacing: Theme.Space.x8) {
            HStack(alignment: .firstTextBaseline, spacing: Theme.Space.x8) {
                Text("Project context")
                    .textStyle(Theme.Text.bodyBold)
                    .foregroundStyle(Theme.Colors.label)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text(".mel/project/")
                    .textStyle(Theme.Text.codeCaption)
                    .foregroundStyle(Theme.Colors.secondaryLabel)
            }
            .padding(.horizontal, Theme.Space.x4)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: Theme.Size.contextCardMin), spacing: Theme.Space.x10, alignment: .top)], spacing: Theme.Space.x10) {
                ForEach(files) { file in
                    contextCard(file)
                }
            }
        }
    }

    private func contextCard(_ file: ContextFile) -> some View {
        VStack(alignment: .leading, spacing: Theme.Space.x6) {
            HStack(spacing: Theme.Space.x8) {
                DesignIcon(glyph: .doc, size: Theme.Size.checkIcon)
                    .foregroundStyle(Theme.Colors.accent)
                Text(file.name)
                    .textStyle(Theme.Text.codeBold)
                    .foregroundStyle(Theme.Colors.label)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text(file.state)
                    .textStyle(Theme.Text.caption)
                    .foregroundStyle(Theme.Colors.secondaryLabel)
            }
            Text(file.about)
                .textStyle(Theme.Text.calloutLoose)
                .foregroundStyle(Theme.Colors.bodyLabel)
            if let sample = file.sample {
                Text(sample)
                    .textStyle(Theme.Text.calloutLoose)
                    .foregroundStyle(Theme.Colors.label)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(EdgeInsets(top: Theme.Space.x6, leading: Theme.Space.x8, bottom: Theme.Space.x6, trailing: Theme.Space.x8))
                    .background(Theme.Colors.fill, in: RoundedRectangle(cornerRadius: Theme.Radius.code))
            }
        }
        .padding(EdgeInsets(top: Theme.Space.x12, leading: Theme.Space.x14, bottom: Theme.Space.x12, trailing: Theme.Space.x14))
        .frame(maxWidth: .infinity, alignment: .leading)
        .surface(.clear, .outlineList, in: RoundedRectangle(cornerRadius: Theme.Radius.card))
        .accessibilityElement(children: .combine)
    }

    private var principlesCard: some View {
        VStack(alignment: .leading, spacing: Theme.Space.x6) {
            HStack(spacing: Theme.Space.x8) {
                Text("principles.md")
                    .textStyle(Theme.Text.codeBold)
                    .foregroundStyle(Theme.Colors.label)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("Rules every spec and agent must follow")
                    .textStyle(Theme.Text.caption)
                    .foregroundStyle(Theme.Colors.secondaryLabel)
            }
            VStack(alignment: .leading, spacing: Theme.Space.x4) {
                ForEach(Array(principles.enumerated()), id: \.offset) { index, rule in
                    HStack(alignment: .firstTextBaseline, spacing: 0) {
                        Text("\(index + 1).")
                            .textStyle(Theme.Text.bodyLoose)
                            .frame(width: Theme.Space.x18, alignment: .leading)
                        Text(rule).textStyle(Theme.Text.bodyLoose)
                    }
                    .foregroundStyle(Theme.Colors.label)
                }
            }
            Button("Add Rule") { isAddingRule = true }
                .buttonStyle(DesignButtonStyle(role: .secondary, height: Theme.Size.buttonMini, leading: Theme.Space.x10, trailing: Theme.Space.x10, text: Theme.Text.callout, elevation: .buttonSmall))
        }
        .padding(EdgeInsets(top: Theme.Space.x12, leading: Theme.Space.x14, bottom: Theme.Space.x12, trailing: Theme.Space.x14))
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.Colors.fill, in: RoundedRectangle(cornerRadius: Theme.Radius.card))
    }

    private var principles: [String] {
        Self.listItems(setup?.context?.principles ?? "")
    }

    // MARK: Footer

    private var footer: some View {
        HStack(spacing: Theme.Space.x10) {
            VStack(alignment: .leading, spacing: Theme.Space.x4) {
                Text(isNewProject
                     ? "Nothing to scan yet. Mel fills these files as your first spec is approved."
                     : "Specs will link to existing code by path, so agents extend what is already built instead of rebuilding it.")
                    .textStyle(Theme.Text.callout)
                    .foregroundStyle(Theme.Colors.secondaryLabel)
                Button("Skip for now. Specs won’t know your code until you set this up.", action: onDone)
                    .buttonStyle(DesignLinkStyle())
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Button("Edit Files") { state.showContext(of: project) }
                .buttonStyle(DesignButtonStyle(role: .secondary, leading: Theme.Space.x16, trailing: Theme.Space.x16, text: Theme.Text.body))
                .disabled(isRunning)
            Button("Save and Start a Spec", action: onDone)
                .buttonStyle(DesignButtonStyle(leading: Theme.Space.x18, trailing: Theme.Space.x12, keyHint: "⌘↩"))
                .keyboardShortcut(.return, modifiers: .command)
                .disabled(isRunning)
        }
        .padding(.top, Theme.Space.x2)
    }

    private func addRule() {
        let text = rule.trimmingCharacters(in: .whitespaces)
        rule = ""
        guard !text.isEmpty else { return }
        do { try state.addRule(text, to: project) } catch { self.error = error.localizedDescription }
    }

    /// First paragraph that is not a heading: the card's sample.
    static func firstParagraph(_ markdown: String) -> String? {
        markdown.components(separatedBy: "\n\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { !$0.isEmpty && !$0.hasPrefix("#") }
    }

    /// "- rule" and "1. rule" lines.
    static func listItems(_ markdown: String) -> [String] {
        markdown.split(whereSeparator: \.isNewline).compactMap { line in
            let line = line.trimmingCharacters(in: .whitespaces)
            if line.hasPrefix("- ") { return String(line.dropFirst(2)) }
            if let dot = line.firstIndex(of: "."), line[..<dot].allSatisfy(\.isNumber), !line[..<dot].isEmpty {
                return line[line.index(after: dot)...].trimmingCharacters(in: .whitespaces)
            }
            return nil
        }
    }
}

/// The design's two-option segmented control (A3): grey track, white selected segment.
struct SegmentedPicker<Value: Hashable>: View {
    @Binding var selection: Value
    let options: [(Value, String)]

    var body: some View {
        HStack(spacing: Theme.Space.x2) {
            ForEach(options, id: \.0) { value, label in
                let isSelected = value == selection
                Button { selection = value } label: {
                    Text(label)
                        .textStyle(isSelected ? Theme.Text.calloutMedium : Theme.Text.callout)
                        .foregroundStyle(Theme.Colors.label)
                        .padding(.horizontal, Theme.Space.x12)
                        .frame(height: Theme.Size.buttonMini)
                        .surface(isSelected ? Theme.Colors.background : .clear, isSelected ? .segmentSelected : .init(), in: Capsule())
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
        .padding(Theme.Space.x2)
        .frame(height: Theme.Size.button)
        .background(Theme.Colors.badgeFill, in: Capsule())
    }
}

private extension String {
    func trimmingSuffix(_ suffix: String) -> String { hasSuffix(suffix) ? String(dropLast(suffix.count)) : self }
}

#Preview("Existing code") {
    ProjectSetupView(project: PreviewData.project, onChange: {}, onDone: {})
        .environment(PreviewData.appState([], projectSetup: PreviewData.projectSetup))
        .frame(width: Theme.Size.windowWidth, height: Theme.Size.windowHeight)
}

#Preview("New project") {
    ProjectSetupView(project: PreviewData.project, isNewProject: true, onChange: {}, onDone: {})
        .environment(PreviewData.appState([], projectSetup: PreviewData.projectSetup))
        .frame(width: Theme.Size.windowWidth, height: Theme.Size.windowHeight)
}

#Preview("Reading") {
    ProjectSetupView(project: PreviewData.project, onChange: {}, onDone: {})
        .environment(PreviewData.appState([], projectSetup: PreviewData.projectSetupRunning))
        .frame(width: Theme.Size.windowWidth, height: Theme.Size.windowHeight)
}

#Preview("Failed") {
    var setup = PreviewData.projectSetupRunning
    setup.isRunning = false
    setup.lastError = "Claude Code's reply couldn't be read."
    return ProjectSetupView(project: PreviewData.project, onChange: {}, onDone: {})
        .environment(PreviewData.appState([], projectSetup: setup))
        .frame(width: Theme.Size.windowWidth, height: Theme.Size.windowHeight)
}

#Preview("Sidebar, saved context") {
    ProjectSetupView(project: PreviewData.project, readsOnAppear: false, onChange: {}, onDone: {})
        .environment(PreviewData.appState([], contexts: [PreviewData.project.id: PreviewData.context], branches: [PreviewData.project.id: "main"]))
        .frame(width: Theme.Size.windowWidth, height: Theme.Size.windowHeight)
}

#Preview("Sidebar, not read yet") {
    ProjectSetupView(project: PreviewData.project, readsOnAppear: false, onChange: {}, onDone: {})
        .environment(PreviewData.appState([]))
        .frame(width: Theme.Size.windowWidth, height: Theme.Size.windowHeight)
}
