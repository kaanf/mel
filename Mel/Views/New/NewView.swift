import SwiftUI
import UniformTypeIdentifiers
import MelSpec

/// V2-1 New (design/v2 V2-1-New): one box. Mel guesses the size from the words and shows it as a
/// chip the user can change (OQ #27); everything else is a default from Settings › Specs.
struct NewView: View {
    @Environment(AppState.self) private var state
    @AppStorage("fillGaps") private var fillsGaps = true
    @State var idea = ""
    /// The size the user picked on the chip; nil while Mel's guess stands.
    @State private var size: SpecSize?
    @State private var files: [URL] = []
    @State private var isAttaching = false
    @State private var error: String?
    /// A New product gets its own folder, so Start asks what it is called first.
    @State private var isNaming = false
    @State private var name = ""
    /// GH-2: where the new product's code lives.
    @State private var home = RepoChoice(place: .mac)
    @State private var isCreating = false
    /// The spec was made but GitHub failed: New closes once the alert is read.
    @State private var startsAfterError = false
    @FocusState private var isFocused: Bool
    /// The spec was made; the board takes over.
    var onStart: () -> Void = {}

    private static let examples = [
        ("A new app idea", "An app for my yoga studio where members book classes, buy class packs and get reminders."),
        ("A feature", "Members can filter the weekly schedule by teacher and see a short teacher profile on each class."),
        ("A bug", "Two quick taps on Book create two bookings and take two credits."),
    ]

    private var project: Project? { state.currentProject }
    private var text: String { idea.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var planned: SpecSize { size ?? SpecSize.guess(from: idea, hasProject: project != nil) }
    private var canStart: Bool { !text.isEmpty && state.agent.isReady }

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Space.x16) {
                Text("What do you want to build?").textStyle(Theme.Text.title1).accessibilityAddTraits(.isHeader)
                Text("Plain words are fine. Mel asks a few questions, then writes the plan for your agent.")
                    .textStyle(Theme.Text.introTight)
                    .foregroundStyle(Theme.Colors.secondaryLabel)
                    .multilineTextAlignment(.center)
                    .padding(.bottom, Theme.Space.x8)
                box
                if text.isEmpty {
                    VStack(spacing: Theme.Space.x8) {
                        Text("Or try one").textStyle(Theme.Text.callout).foregroundStyle(Theme.Colors.secondaryLabel)
                        HStack(spacing: Theme.Space.x8) {
                            ForEach(Self.examples, id: \.0) { example in
                                Button(example.0) {
                                    idea = example.1
                                    size = nil
                                }
                                .buttonStyle(BoardPillStyle(kind: .quiet, height: Theme.Size.chip))
                            }
                        }
                    }
                    .padding(.top, Theme.Space.x8)
                } else {
                    Text(note)
                        .textStyle(Theme.Text.calloutLoose)
                        .foregroundStyle(Theme.Colors.secondaryLabel)
                        .multilineTextAlignment(.center)
                }
            }
            .foregroundStyle(Theme.Colors.label)
            .frame(maxWidth: Theme.Size.newWidth)
            .padding(.vertical, Theme.Space.x48)
            .padding(.horizontal, Theme.Space.x32)
            .frame(maxWidth: .infinity)
        }
        .defaultScrollAnchor(.center)
        .scrollBounceBehavior(.basedOnSize)
        .background(Theme.Colors.background)
        .ignoresSafeArea(.container, edges: .top)
        .toolbar(removing: .title)
        .navigationTitle("New")
        .animation(.board, value: text.isEmpty)
        .animation(.board, value: planned)
        .animation(.board, value: files)
        .animation(.easeOut(duration: 0.15), value: isFocused)
        .onAppear { isFocused = true }
        .onChange(of: idea) { size = nil }
        .fileImporter(isPresented: $isAttaching, allowedContentTypes: [.item], allowsMultipleSelection: true) { result in
            if case .success(let urls) = result { files += urls.filter { !files.contains($0) } }
        }
        .sheet(isPresented: $isNaming) { naming }
        .alert("Couldn’t Start", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil; if startsAfterError { onStart() } } })) {
        } message: {
            Text(error ?? "")
        }
    }

    private var box: some View {
        VStack(alignment: .leading, spacing: 0) {
            editor
            if !files.isEmpty {
                FlowLayout(spacing: Theme.Space.x6) {
                    ForEach(files, id: \.self) { file in
                        HStack(spacing: Theme.Space.x6) {
                            Text(file.lastPathComponent).textStyle(Theme.Text.caption)
                            Button { files.removeAll { $0 == file } } label: {
                                DesignIcon(glyph: .close, size: Theme.Size.removeIcon, weight: 2.4)
                                    .foregroundStyle(Theme.Colors.secondaryLabel)
                                    .frame(width: Theme.Size.removeButton, height: Theme.Size.removeButton)
                                    .contentShape(Circle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Remove \(file.lastPathComponent)")
                        }
                        .padding(.leading, Theme.Space.x8)
                        .padding(.trailing, Theme.Space.x4)
                        .frame(height: Theme.Size.buttonMini)
                        .background(Theme.Colors.fill, in: RoundedRectangle(cornerRadius: Theme.Radius.code))
                    }
                }
                .padding(.horizontal, Theme.Space.x12)
            }
            HStack(spacing: Theme.Space.x8) {
                Button { isAttaching = true } label: {
                    DesignIcon(glyph: .paperclip, size: Theme.Size.attachIcon, weight: 1.6)
                        .foregroundStyle(Theme.Colors.bodyLabel)
                        .frame(width: Theme.Size.attachButton, height: Theme.Size.attachButton)
                        .background(Theme.Colors.chipFill, in: Circle())
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Add files")
                .help("Add files: a log, a screenshot, a document")
                if !text.isEmpty { sizeChip.transition(.opacity.combined(with: .scale(scale: 0.92, anchor: .leading))) }
                Spacer(minLength: 0)
                Button("Start", action: start)
                    .buttonStyle(AccentPillStyle(padding: Theme.Space.x16, hint: "⌘↩"))
                    .keyboardShortcut(.return, modifiers: .command)
                    .disabled(!canStart)
            }
            .padding(EdgeInsets(top: Theme.Space.x8, leading: Theme.Space.x12, bottom: Theme.Space.x10, trailing: Theme.Space.x10))
            .frame(minHeight: Theme.Size.newBoxFooter)
        }
        .surface(Theme.Colors.background, isFocused ? .ideaBoxFocused : .ideaBox, in: RoundedRectangle(cornerRadius: Theme.Radius.large))
        .background {
            if isFocused {
                RoundedRectangle(cornerRadius: Theme.Radius.large + 3.5).fill(Theme.Colors.focusHalo).padding(-3.5)
            }
        }
        .dropDestination(for: URL.self) { urls, _ in
            files += urls.filter { !files.contains($0) }
            return !urls.isEmpty
        }
    }

    /// 15/23 text, 5 lines, padding 16/18/8 as drawn. A multi-line TextField ignores line height; TextEditor honors it.
    private var editor: some View {
        let style = Theme.Text.lead
        let inset: CGFloat = 5   // NSTextView's line fragment padding
        return TextEditor(text: $idea)
            .font(style.font)
            .lineHeight(.exact(points: style.lineHeight!))
            .scrollContentBackground(.hidden)
            .scrollIndicators(.never)
            .focusEffectDisabled()
            .focused($isFocused)
            .overlay(alignment: .topLeading) {
                if idea.isEmpty {
                    Text("A new app, a feature, or a bug. Paste an issue link or drop a log.")
                        .font(style.font)
                        .lineHeight(.exact(points: style.lineHeight!))
                        .foregroundStyle(Theme.Colors.tertiary)
                        .padding(.horizontal, inset)
                        .allowsHitTesting(false)
                }
            }
            .frame(height: style.lineHeight! * CGFloat(Theme.Size.newIdeaLines) - style.glyphShift)
            .padding(EdgeInsets(top: Theme.Space.x16 + style.glyphShift, leading: Theme.Space.x18 - inset, bottom: Theme.Space.x8, trailing: Theme.Space.x18 - inset))
            .accessibilityLabel("Describe the work")
    }

    private var sizeChip: some View {
        Button {
            // Only a new product works without a project.
            guard project != nil else { return }
            let order: [SpecSize] = [.quickFix, .feature, .product]
            size = order[(order.firstIndex(of: planned)! + 1) % order.count]
        } label: {
            HStack(spacing: Theme.Space.x6) {
                Text(planned.boardLabel).textStyle(Theme.Text.calloutBold)
                Text("· \(chipNote)").textStyle(Theme.Text.callout).lineLimit(1)
                if project != nil { DesignIcon(glyph: .popUp, size: Theme.Size.popUpHeight, weight: 1.6).frame(width: Theme.Size.popUpWidth) }
            }
            .foregroundStyle(Theme.Colors.likely)
            .padding(.horizontal, Theme.Space.x12)
            .frame(height: Theme.Size.chip)
            .surface(Theme.Colors.accentSelectedFill, .sizeChip, in: Capsule())
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Planned as \(planned.boardLabel)." + (project != nil ? " Click to change." : ""))
    }

    private var chipNote: String {
        switch planned {
        case .quickFix: "1 file"
        case .feature: "in \(project?.name ?? "")"
        case .product: "new folder"
        }
    }

    /// Why Mel guessed this size, under the box.
    private var note: String {
        if !state.agent.isReady { return "Claude Code isn’t ready. Check Settings › Agents." }
        guard let project else { return "Mel makes a new folder for it and also plans the screens." }
        let why = if size != nil {
            "You picked \(planned.boardLabel)."
        } else {
            switch planned {
            case .quickFix: "Sounds like a bug in \(project.name), so Mel keeps it to one short spec."
            case .feature: "Sounds like a change to \(project.name), so Mel plans it on top of your code."
            case .product: "Sounds like a new app, so Mel also plans the screens."
            }
        }
        return why + " Click the chip if it’s wrong."
    }

    private func start() {
        guard canStart else { return }
        if planned == .product {
            home = RepoChoice(place: state.github.login == nil ? .mac : .newRepo, name: RepoChoice.repoName(name))
            isNaming = true
        } else {
            create(named: Spec.untitledName)
        }
    }

    /// With `Spec.untitledName` the intake names the spec (and a new product's folder).
    private func create(named name: String) {
        do {
            // A new product gets its own folder; a feature or a fix goes into the project.
            _ = try state.createSpec(name: name, idea: text, size: planned, project: planned == .product ? nil : project, fillGaps: fillsGaps, files: files)
            onStart()
        } catch {
            self.error = error.localizedDescription
        }
    }

    /// GH-2: the name of a new product, asked once after Start, and where its code lives. Its folder in ~/Developer takes the name.
    private var naming: some View {
        let typed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let onGitHub = home.place != .mac
        return VStack(alignment: .leading, spacing: Theme.Space.x16) {
            VStack(alignment: .leading, spacing: Theme.Space.x6) {
                Text("Name your product").textStyle(Theme.Text.headline).accessibilityAddTraits(.isHeader)
                Text("Mel makes a folder for it in ~/Developer. You can rename the spec later.")
                    .textStyle(Theme.Text.calloutLoose)
                    .foregroundStyle(Theme.Colors.secondaryLabel)
                    .fixedSize(horizontal: false, vertical: true)
            }
            TextField("For example: Yoga Studio Booking", text: $name)
                .textFieldStyle(.plain)
                .textStyle(Theme.Text.body)
                .padding(.horizontal, Theme.Space.x10)
                .frame(height: Theme.Size.buttonLarge)
                .surface(Theme.Colors.background, .focus, in: RoundedRectangle(cornerRadius: Theme.Radius.row))
                .onSubmit { if !typed.isEmpty, home.isReady(connecting: false) { finishNaming(typed) } }
                .onChange(of: name) { old, new in
                    // The repo name follows the product's until it's typed over.
                    if home.name == RepoChoice.repoName(old) { home.name = RepoChoice.repoName(new) }
                }
                .accessibilityLabel("Name")
            RepoChoiceView(choice: $home)
            HStack(spacing: Theme.Space.x12) {
                Button("Cancel") { isNaming = false }
                    .buttonStyle(DesignLinkStyle())
                    .keyboardShortcut(.cancelAction)
                Spacer(minLength: 0)
                if isCreating { ProgressView().controlSize(.small) }
                // A repo needs its name now; only a product on this Mac can wait for Mel's.
                if !onGitHub {
                    Button("Let Mel name it") { finishNaming(Spec.untitledName) }
                        .buttonStyle(BoardPillStyle(height: Theme.Size.buttonLarge, padding: Theme.Space.x16))
                        .help("Mel names it from your idea after its first read")
                }
                Button(home.confirm(connecting: false)) { finishNaming(typed) }
                    .buttonStyle(AccentPillStyle(padding: Theme.Space.x16, hint: "↩"))
                    .keyboardShortcut(.defaultAction)
                    .disabled(typed.isEmpty || !home.isReady(connecting: false) || isCreating)
            }
        }
        .foregroundStyle(Theme.Colors.label)
        .padding(Theme.Space.x24)
        .frame(width: Theme.Size.repoSheet)
        .animation(.board, value: home)
        .background(Theme.Colors.background)
    }

    private func finishNaming(_ name: String) {
        switch home.place {
        case .mac:
            isNaming = false
            create(named: name)
        case .newRepo:
            let (repoName, isPrivate) = (home.name.trimmingCharacters(in: .whitespaces), home.isPrivate)
            isCreating = true
            Task {
                defer { isCreating = false }
                isNaming = false
                do {
                    _ = try state.createSpec(name: name, idea: text, size: planned, project: nil, fillGaps: fillsGaps, files: files)
                } catch {
                    self.error = error.localizedDescription
                    return
                }
                guard let project = state.currentProject else { return onStart() }
                do {
                    try await state.createRepo(for: project, name: repoName, isPrivate: isPrivate)
                    onStart()
                } catch {
                    startsAfterError = true
                    self.error = "The spec is made, but GitHub didn’t create the repo: \(error.localizedDescription) Connect it later from the project menu."
                }
            }
        case .existing:
            guard let repo = home.repo else { return }
            isCreating = true
            Task {
                defer { isCreating = false }
                do {
                    let project = try await state.cloneProject(repo)
                    isNaming = false
                    _ = try state.createSpec(name: name, idea: text, size: planned, project: project, fillGaps: fillsGaps, files: files)
                    onStart()
                } catch {
                    isNaming = false
                    self.error = error.localizedDescription
                }
            }
        }
    }
}

#Preview("Feature guessed") {
    NewView(idea: "Members can filter the weekly schedule by teacher and see a short teacher profile on each class.")
        .environment(PreviewData.appState([]))
        .frame(width: 1036, height: 800)
}

#Preview("Empty") {
    NewView()
        .environment(PreviewData.appState([]))
        .frame(width: 1036, height: 800)
}

#Preview("A bug") {
    NewView(idea: "Two quick taps on Book create two bookings and take two credits.")
        .environment(PreviewData.appState([]))
        .frame(width: 1036, height: 800)
}

#Preview("From an idea, no project") {
    NewView(idea: "An app for my yoga studio where members book classes.")
        .environment(PreviewData.appState([], projects: []))
        .frame(width: Theme.Size.windowWidth, height: 800)
}
