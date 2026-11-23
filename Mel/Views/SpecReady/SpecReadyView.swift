import SwiftUI
import MelSpec

/// B7 Spec ready (design/v2 Native-4-Done): file tiles, P1 tasks with Copy Prompt, the start command,
/// Write AGENTS.md and Commit. "Keep the spec in sync" and Use Codex Instead are hidden in v0.3 (V2 §2).
struct SpecReadyView: View {
    let session: SpecSession
    @Environment(AppState.self) private var state
    @State private var summaries: [DocKind: DocSummary] = [:]
    @State private var writesAgents = false
    @State private var committed = false
    @State private var confirmingInit = false
    @State private var copied: Int?
    @State private var error: String?

    private var spec: Spec { session.spec }
    private var files: [DocKind] { spec.size.files }
    private var tasks: [SpecTask] { session.tasks }
    private var firstTasks: [SpecTask] { tasks.filter { $0.priority == "P1" } }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Space.x22) {
                VStack(alignment: .leading, spacing: Theme.Space.x6) {
                    HStack(spacing: Theme.Space.x8) {
                        DesignIcon(glyph: .checkCircle, size: Theme.Size.readyIcon).foregroundStyle(Theme.Colors.success)
                        Text("Spec ready").textStyle(Theme.Text.title2).accessibilityAddTraits(.isHeader)
                    }
                    Text(intro).textStyle(Theme.Text.intro).foregroundStyle(Theme.Colors.bodyLabel)
                }
                LazyVGrid(columns: [GridItem(.adaptive(minimum: Theme.Size.fileTileMin), spacing: Theme.Space.x8)], spacing: Theme.Space.x8) {
                    ForEach(files, id: \.self) { kind in
                        VStack(alignment: .leading, spacing: Theme.Space.x2) {
                            Text(kind.fileName).textStyle(Theme.Text.codeCaptionBold)
                            Text(tileLine(kind)).textStyle(Theme.Text.callout).foregroundStyle(Theme.Colors.bodyLabel)
                        }
                        .padding(.vertical, Theme.Space.x10)
                        .padding(.horizontal, Theme.Space.x12)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                        .background(Theme.Colors.fill, in: RoundedRectangle(cornerRadius: Theme.Radius.box))
                        .accessibilityElement(children: .combine)
                    }
                }
                startBuilding
                settings
            }
            .foregroundStyle(Theme.Colors.label)
            .frame(maxWidth: Theme.Size.specReadyWidth)
            .padding(.vertical, Theme.Space.x40)
            .padding(.horizontal, Theme.Space.x32)
            .frame(maxWidth: .infinity)
        }
        .background(Theme.Colors.background)
        // Drawn without a toolbar row: the content starts 40 pt below the window top.
        .ignoresSafeArea(.container, edges: .top)
        .toolbar(removing: .title)
        .toolbarBackgroundVisibility(.hidden, for: .windowToolbar)
        .navigationTitle(spec.name)
        .task {
            // The per-task prompts the start command points at.
            do { _ = try await session.writeTaskPrompts() } catch { self.error = error.localizedDescription }
            for kind in files { summaries[kind] = session.summary(kind) }
        }
        .task(id: copied) {
            guard copied != nil else { return }
            try? await Task.sleep(for: .seconds(2))
            copied = nil
        }
        .confirmationDialog("\(spec.project.lastPathComponent) is not a Git repository.", isPresented: $confirmingInit) {
            Button("Create Repository and Commit", action: commit)
        } message: {
            Text("Mel runs git init in the project folder, then commits the spec.")
        }
        .alert("Couldn’t Finish", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
        } message: {
            Text(error ?? "")
        }
    }

    private var intro: String {
        let approved = files.count == 1 ? "1 file approved" : "\(files.count) files approved"
        let analyze: String = switch spec.analyze {
        case .passed: ", Analyze passed"
        case .issues(let n): n == 1 ? ", 1 Analyze issue left open" : ", \(n) Analyze issues left open"
        default: ""
        }
        return spec.size == .quickFix
            ? "\(approved). SPEC.md says what breaks, what should happen and how to verify the fix."
            : "\(approved)\(analyze). Every task names the requirements it builds and how to prove it works."
    }

    /// The tile's short summary ("5 stories, 15 criteria, 3 quality").
    private func tileLine(_ kind: DocKind) -> String {
        let s = summaries[kind] ?? DocSummary()
        switch kind {
        case .product: return "Goal, users, success metric"
        case .requirements: return "\(n(s.stories, "story", "stories")), \(n(s.criteria, "criterion", "criteria")), \(s.quality) quality"
        case .experience: return "\(n(s.flows, "flow", "flows")), \(n(s.screens, "screen", "screens"))"
        case .architecture: return "Modules, data, API, decisions"
        case .tasks:
            let parallel = tasks.count { !$0.parallelWith.isEmpty }
            return n(s.tasks, "task", "tasks") + (parallel > 0 ? ", \(parallel) run in parallel" : "")
        case .spec: return "What breaks, the fix, how to verify"
        }
    }

    private func n(_ count: Int, _ one: String, _ many: String) -> String { "\(count) \(count == 1 ? one : many)" }

    private var startBuilding: some View {
        VStack(alignment: .leading, spacing: Theme.Space.x8) {
            HStack(alignment: .firstTextBaseline, spacing: Theme.Space.x8) {
                Text("Start building").textStyle(Theme.Text.bodyBold).frame(maxWidth: .infinity, alignment: .leading).accessibilityAddTraits(.isHeader)
                if !firstTasks.isEmpty {
                    Text("P1 tasks first. They make the MVP on their own.").textStyle(Theme.Text.caption).foregroundStyle(Theme.Colors.secondaryLabel)
                }
            }
            .padding(.horizontal, Theme.Space.x4)
            VStack(spacing: 0) {
                ForEach(firstTasks) { task in
                    taskRow(task)
                        .overlay(alignment: .bottom) { Rectangle().fill(Theme.Colors.separatorTable).frame(height: Theme.Size.hairline) }
                }
                HStack(spacing: Theme.Space.x10) {
                    Text(session.startCommand)
                        .textStyle(Theme.Text.code)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .textSelection(.enabled)
                        .padding(.vertical, Theme.Space.x6)
                        .padding(.horizontal, Theme.Space.x10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Theme.Colors.fill, in: RoundedRectangle(cornerRadius: Theme.Radius.code))
                    Button("Open in Terminal") { session.openStartCommandInTerminal() }
                        .buttonStyle(DesignButtonStyle(height: Theme.Size.button, leading: Theme.Space.x14, trailing: Theme.Space.x14, text: Theme.Text.calloutBold, elevation: .init()))
                }
                .padding(.vertical, Theme.Space.x10)
                .padding(.horizontal, Theme.Space.x14)
            }
            .surface(.clear, .outlineList, in: RoundedRectangle(cornerRadius: Theme.Radius.card))
        }
    }

    private func taskRow(_ task: SpecTask) -> some View {
        HStack(alignment: .top, spacing: Theme.Space.x12) {
            Text("\(task.number)")
                .textStyle(Theme.Text.codeBlock)
                .foregroundStyle(Theme.Colors.secondaryLabel)
                .frame(width: Theme.Size.taskNumber, alignment: .leading)
            VStack(alignment: .leading, spacing: Theme.Space.x3) {
                HStack(spacing: Theme.Space.x8) {
                    Text(task.title).textStyle(Theme.Text.bodyBold)
                    Text(task.priority)
                        .textStyle(Theme.Text.micro)
                        .padding(.horizontal, Theme.Space.x6)
                        .frame(height: Theme.Size.priorityBadge)
                        .background(Theme.Colors.badgeFill, in: Capsule())
                    if let order = order(task) {
                        Text(order).textStyle(Theme.Text.caption).foregroundStyle(Theme.Colors.secondaryLabel)
                    }
                }
                Text("Builds \(task.covers.joined(separator: ", ")) · reads \(task.reads)")
                    .textStyle(Theme.Text.callout)
                    .foregroundStyle(Theme.Colors.bodyLabel)
                Text("Verify: \(task.verify)")
                    .textStyle(Theme.Text.codeCaptionLoose)
                    .foregroundStyle(Theme.Colors.secondaryLabel)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Button(copied == task.number ? "Copied" : "Copy Prompt") {
                state.copy(task.prompt(requirements: session.documents[.requirements] ?? ""))
                copied = task.number
            }
            .buttonStyle(DesignButtonStyle(role: .secondary, height: Theme.Size.buttonSmall, leading: Theme.Space.x12, trailing: Theme.Space.x12, text: Theme.Text.callout))
            .frame(maxHeight: .infinity)
        }
        .fixedSize(horizontal: false, vertical: true)
        .padding(.vertical, Theme.Space.x12)
        .padding(.horizontal, Theme.Space.x14)
        .accessibilityElement(children: .contain)
    }

    /// "Start here" for the first task, "Parallel with 3" when it can run alongside others.
    private func order(_ task: SpecTask) -> String? {
        if !task.parallelWith.isEmpty { return "Parallel with " + task.parallelWith.map(String.init).joined(separator: " and ") }
        return task.number == firstTasks.first?.number ? "Start here" : nil
    }

    private var settings: some View {
        VStack(spacing: 0) {
            HStack(spacing: Theme.Space.x12) {
                VStack(alignment: .leading, spacing: Theme.Space.x2) {
                    Text("Write AGENTS.md").textStyle(Theme.Text.body)
                    Text("Points every agent at the project context, this spec and the per-task prompts.")
                        .textStyle(Theme.Text.caption)
                        .foregroundStyle(Theme.Colors.secondaryLabel)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Toggle("Write AGENTS.md", isOn: $writesAgents)
                    .toggleStyle(DesignSwitchStyle())
                    .labelsHidden()
                    .onChange(of: writesAgents) { _, on in
                        guard on else { return }
                        do { try session.writeAgentsMD() } catch { self.error = error.localizedDescription; writesAgents = false }
                    }
            }
            .frame(minHeight: Theme.Size.projectRow)   // CSS min-height leaves out the padding
            .padding(.vertical, Theme.Space.x8)
            .padding(.horizontal, Theme.Space.x14)
            if session.canCommit {
                Rectangle().fill(Theme.Colors.separatorLight).frame(height: Theme.Size.hairline).padding(.leading, Theme.Space.x14)
                HStack(spacing: Theme.Space.x12) {
                    VStack(alignment: .leading, spacing: Theme.Space.x2) {
                        Text("Commit the spec to Git").textStyle(Theme.Text.body)
                        Text(specsPath)
                            .textStyle(Theme.Text.codeCaption)
                            .foregroundStyle(Theme.Colors.secondaryLabel)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    Button(committed ? "Committed" : "Commit") {
                        if session.isGitRepository { commit() } else { confirmingInit = true }
                    }
                    .buttonStyle(DesignButtonStyle(role: .secondary, height: Theme.Size.buttonSmall, leading: Theme.Space.x12, trailing: Theme.Space.x12, text: Theme.Text.callout))
                    .disabled(committed)
                }
                .frame(minHeight: Theme.Size.projectRow)
                .padding(.vertical, Theme.Space.x8)
                .padding(.horizontal, Theme.Space.x14)
            }
        }
        .background(Theme.Colors.fill, in: RoundedRectangle(cornerRadius: Theme.Radius.card))
    }

    /// "~/Developer/yoga-studio-booking/specs"
    private var specsPath: String {
        let path = spec.folder.deletingLastPathComponent().path(percentEncoded: false).abbreviatingHome
        return path.hasSuffix("/") ? String(path.dropLast()) : path
    }

    private func commit() {
        Task {
            do {
                try await session.finish(commitToGit: true)
                committed = true
            } catch {
                self.error = error.localizedDescription
            }
        }
    }
}

#Preview("Spec ready") {
    NavigationStack {
        SpecReadyView(session: PreviewData.doneSession)
    }
    .environment(PreviewData.appState([PreviewData.done]))
    .frame(width: 1048, height: 800)
}
