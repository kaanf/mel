import SwiftUI
import MelSpec

/// V2-3 Ready (design/v2 V2-3-Ready): one primary action, Build with Claude Code. Task prompts and
/// the spec files are one click away, closed by default. Hidden (OQ #28): Use Codex instead, and
/// the agent asking here before it changes the plan.
struct ReadyView: View {
    let session: SpecSession
    @Environment(\.openSettings) private var openSettings
    @AppStorage("settingsTab") private var settingsTab = SettingsView.Pane.agents
    @AppStorage("showTokens") private var showsTokens = true
    @AppStorage("commitSpec") private var commitsSpec = true
    @AppStorage("writeAgentsFile") private var writesAgentsFile = true
    @State private var showsTasks = false
    @State private var showsFiles = false
    @State private var copied: Int?

    private var spec: Spec { session.spec }
    private var tasks: [SpecTask] { session.tasks }
    private var fileNames: [String] { spec.size.files.map(\.fileName) + ["DECISIONS.md"] }

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Space.x20) {
                VStack(spacing: Theme.Space.x10) {
                    DesignIcon(glyph: .check, size: Theme.Size.readyDiscCheck)
                        .foregroundStyle(Theme.Colors.success)
                        .frame(width: Theme.Size.readyDisc, height: Theme.Size.readyDisc)
                        .background(Theme.Colors.readyDisc, in: Circle())
                        .accessibilityHidden(true)
                    Text("Ready to build").textStyle(Theme.Text.title1).accessibilityAddTraits(.isHeader)
                    Text(summary).textStyle(Theme.Text.intro).foregroundStyle(Theme.Colors.bodyLabel).multilineTextAlignment(.center)
                }
                VStack(spacing: Theme.Space.x8) {
                    Button("Build with Claude Code", action: session.build)
                        .buttonStyle(AccentPillStyle(height: Theme.Size.buildButton, padding: Theme.Space.x24, hint: "⌘↩", text: Theme.Text.buildButton, hintText: Theme.Text.callout, gap: Theme.Space.x10, elevation: .buildButton))
                        .keyboardShortcut(.return, modifiers: .command)
                    HStack(spacing: Theme.Space.x4) {
                        Text(spec.size == .quickFix ? "Opens Terminal and starts the fix." : "Opens Terminal and starts with task 1.")
                            .textStyle(Theme.Text.callout)
                            .foregroundStyle(Theme.Colors.secondaryLabel)
                        switch spec.build {
                        case .building: Button("Mark as Done") { session.setBuild(.done) }.buttonStyle(DesignLinkStyle())
                        case .done: Button("Not done yet") { session.setBuild(.building) }.buttonStyle(DesignLinkStyle())
                        case nil: EmptyView()
                        }
                    }
                    if let error = session.lastError {
                        Text(error).textStyle(Theme.Text.callout).foregroundStyle(Theme.Colors.cautionText)
                    }
                }
                next
                details
                HStack(spacing: Theme.Space.x4) {
                    Text(defaults).textStyle(Theme.Text.calloutLoose).foregroundStyle(Theme.Colors.secondaryLabel)
                    Button("Change in Settings") {
                        settingsTab = .specs
                        openSettings()
                    }
                    .buttonStyle(DesignLinkStyle(text: Theme.Text.calloutLoose))
                }
            }
            .foregroundStyle(Theme.Colors.label)
            .frame(maxWidth: Theme.Size.readyWidth)
            .padding(EdgeInsets(top: Theme.Size.readyTop, leading: Theme.Space.x32, bottom: Theme.Space.x40, trailing: Theme.Space.x32))
            .frame(maxWidth: .infinity)
        }
        .background(Theme.Colors.background)
        // Drawn without a toolbar row.
        .ignoresSafeArea(.container, edges: .top)
        .toolbar(removing: .title)
        .toolbarBackgroundVisibility(.hidden, for: .windowToolbar)
        .navigationTitle(spec.name)
    }

    /// "3 stories in the first version, 2 for later. 7 tasks, and every task says how it will be checked. Written with 41k tokens…"
    private var summary: String {
        var parts: [String] = []
        let stories = session.stories
        let first = stories.count { $0.isFirst }
        if !stories.isEmpty {
            let later = stories.count - first
            parts.append("\(first) \(first == 1 ? "story" : "stories") in the first version" + (later > 0 ? ", \(later) for later." : "."))
        }
        if !tasks.isEmpty {
            let count = "\(tasks.count) \(tasks.count == 1 ? "task" : "tasks")"
            parts.append(tasks.allSatisfy { !$0.verify.isEmpty } ? "\(count), and every task says how it will be checked." : "\(count).")
        }
        if spec.size == .quickFix { parts.append("SPEC.md says what breaks, what should happen and how to check the fix.") }
        if showsTokens, spec.tokenTotal > 0 { parts.append("Written with \(TokenStep.text(spec.tokenTotal)) tokens of your Claude Code usage.") }
        return parts.joined(separator: " ")
    }

    private var steps: [String] {
        [
            spec.size == .quickFix ? "Claude Code reads SPEC.md, makes the fix and runs its check." : "Claude Code builds the tasks in order and runs each check before moving on.",
            "When it’s built, mark this spec as Done. It moves to Done in the sidebar.",
        ]
    }

    private var next: some View {
        VStack(alignment: .leading, spacing: Theme.Space.x10) {
            Text("What happens next").textStyle(Theme.Text.calloutBold).foregroundStyle(Theme.Colors.bodyLabel)
            ForEach(Array(steps.enumerated()), id: \.offset) { index, text in
                HStack(alignment: .top, spacing: Theme.Space.x10) {
                    Text("\(index + 1)")
                        .textStyle(Theme.Text.captionBold)
                        .frame(width: Theme.Size.nextNumber, height: Theme.Size.nextNumber)
                        .surface(Theme.Colors.background, .article, in: Circle())
                    Text(text).textStyle(Theme.Text.bodyLoose)
                }
                .accessibilityElement(children: .combine)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Theme.Space.x16)
        .background(Theme.Colors.fill, in: RoundedRectangle(cornerRadius: Theme.Radius.card))
    }

    private var details: some View {
        VStack(spacing: 0) {
            if !tasks.isEmpty {
                disclosure("Task prompts and checks", trailing: "\(tasks.count) \(tasks.count == 1 ? "task" : "tasks")", isOpen: $showsTasks)
                if showsTasks {
                    VStack(spacing: Theme.Space.x8) {
                        ForEach(tasks) { task in
                            VStack(alignment: .leading, spacing: Theme.Space.x4) {
                                HStack(spacing: Theme.Space.x8) {
                                    Text("\(task.number). \(task.title)").textStyle(Theme.Text.bodyBold).frame(maxWidth: .infinity, alignment: .leading)
                                    Button(copied == task.number ? "Copied" : "Copy Prompt") {
                                        session.copyPrompt(of: task)
                                        copied = task.number
                                    }
                                    .buttonStyle(BoardPillStyle(kind: .quiet, height: Theme.Size.buttonMini, padding: Theme.Space.x10, text: Theme.Text.caption))
                                    .accessibilityLabel("Copy the prompt of task \(task.number)")
                                }
                                if !task.verify.isEmpty {
                                    Text(task.verify).textStyle(Theme.Text.codeCaptionLoose).foregroundStyle(Theme.Colors.bodyLabel).textSelection(.enabled)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, Theme.Space.x10)
                            .padding(.horizontal, Theme.Space.x12)
                            .surface(Theme.Colors.background, .fileChip, in: RoundedRectangle(cornerRadius: Theme.Radius.box))
                        }
                    }
                    .padding(EdgeInsets(top: 0, leading: Theme.Space.x14, bottom: Theme.Space.x14, trailing: Theme.Space.x14))
                }
                Rectangle().fill(Theme.Colors.separator).frame(height: Theme.Size.hairline)
            }
            disclosure("Spec files", trailing: "specs/\(spec.folder.lastPathComponent)", isOpen: $showsFiles)
            if showsFiles {
                FlowLayout(spacing: Theme.Space.x6) {
                    ForEach(fileNames, id: \.self) { name in
                        Button { session.openInEditor(name) } label: {
                            Text(name)
                                .textStyle(Theme.Text.codeCaption)
                                .padding(.horizontal, Theme.Space.x10)
                                .frame(height: Theme.Size.button)
                                .surface(Theme.Colors.background, .fileChip, in: RoundedRectangle(cornerRadius: Theme.Radius.row))
                        }
                        .buttonStyle(.plain)
                        .help("Open \(name) in your editor")
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(EdgeInsets(top: 0, leading: Theme.Space.x14, bottom: Theme.Space.x14, trailing: Theme.Space.x14))
            }
        }
        .surface(.clear, .disclosure, in: RoundedRectangle(cornerRadius: Theme.Radius.card))
    }

    private func disclosure(_ title: String, trailing: String, isOpen: Binding<Bool>) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.15)) { isOpen.wrappedValue.toggle() }
        } label: {
            HStack(spacing: Theme.Space.x8) {
                DesignIcon(glyph: .chevronRight, size: Theme.Size.rowChevron).rotationEffect(.degrees(isOpen.wrappedValue ? 90 : 0))
                Text(title).textStyle(Theme.Text.bodyMedium).frame(maxWidth: .infinity, alignment: .leading)
                Text(trailing).textStyle(Theme.Text.callout).foregroundStyle(Theme.Colors.secondaryLabel)
            }
            .padding(.horizontal, Theme.Space.x14)
            .frame(minHeight: Theme.Size.disclosureRow)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityValue(isOpen.wrappedValue ? "Expanded" : "Collapsed")
    }

    /// What Start Building did besides the task prompts, as Settings › Specs says.
    private var defaults: String {
        switch (writesAgentsFile, commitsSpec) {
        case (true, true): "Mel also writes AGENTS.md and commits the spec to Git."
        case (true, false): "Mel also writes AGENTS.md."
        case (false, true): "Mel also commits the spec to Git."
        case (false, false): "Mel doesn’t write AGENTS.md or commit the spec."
        }
    }
}

#Preview("Ready") {
    NavigationStack { ReadyView(session: PreviewData.doneSession) }
        .frame(width: 1036, height: 800)
}

#Preview("Building") {
    NavigationStack { ReadyView(session: PreviewData.buildingSession) }
        .frame(width: 1036, height: 800)
}

#Preview("Quick fix") {
    NavigationStack { ReadyView(session: PreviewData.quickFixDoneSession) }
        .frame(width: 1036, height: 800)
}
