import SwiftUI
import MelSpec

/// V2-6 Settings › Specs (design/v2 V2-6-Settings-Specs): the defaults V2 stopped asking about,
/// and what Mel knows about the current project. Hidden (OQ #28): Default agent and "Ask me before
/// an agent changes the plan"; "Save specs to" is always `specs/`. Spec language isn't drawn (added in 0.4).
struct SpecsSettings: View {
    @Environment(AppState.self) private var state
    @AppStorage("showSidebarFiles") private var showsSidebarFiles = false
    @AppStorage("fillGaps") private var fillsGaps = true
    @AppStorage("showTokens") private var showsTokens = true
    @AppStorage("writeAgentsFile") private var writesAgentsFile = true
    @AppStorage("commitSpec") private var commitsSpec = true
    @State private var editors: [URL] = []
    /// The rule being typed after Add Rule.
    @State private var newRule: String?
    @State private var error: String?
    @FocusState private var isAddingRule: Bool

    var body: some View {
        @Bindable var state = state
        return VStack(alignment: .leading, spacing: Theme.Space.x20) {
            group("Files") {
                toggle("Show spec files in the sidebar", showsSidebarFiles ? "The Markdown files are always listed under the open spec." : "Off: open them from Files on the board. Most people never need them.", $showsSidebarFiles)
                separator
                settingsRow("Open files in", "Used by Open in Editor on the board.") {
                    settingsValue(state.editor.map(Self.name) ?? "Default app") {
                        Picker("Open files in", selection: $state.editor) {
                            Text("Default app").tag(URL?.none)
                            ForEach(editors, id: \.self) { Text(Self.name($0)).tag(URL?.some($0)) }
                        }
                    }
                }
            }
            group("Writing a spec") {
                toggle("Let Mel guess small details", "Each guess is listed on the board so you can check it.", $fillsGaps)
                separator
                toggle("Show token use on the board", "A small total in the board toolbar. Click it to see each step.", $showsTokens)
                separator
                settingsRow("Spec language", "What new specs are written in. Mel itself stays in English.") {
                    settingsValue(state.specLanguage.name) {
                        Picker("Spec language", selection: $state.specLanguage) {
                            ForEach(SpecLanguage.allCases, id: \.self) { Text($0.name).tag($0) }
                        }
                    }
                }
            }
            group("When you start building") {
                toggle("Write AGENTS.md", "Points every agent at the project, this spec and the task prompts.", $writesAgentsFile)
                separator
                toggle("Commit the spec to Git", "One commit with all spec files before the first task.", $commitsSpec)
            }
            if let project = state.currentProject {
                group("Project: \(project.name)") { context(of: project) }
            }
        }
        .foregroundStyle(Theme.Colors.label)
        .padding(EdgeInsets(top: Theme.Space.x20, leading: Theme.Space.x24, bottom: Theme.Space.x28, trailing: Theme.Space.x24))
        .frame(width: Theme.Size.settingsWidth)
        .fixedSize(horizontal: false, vertical: true)
        .background(Theme.Colors.settingsBackground)
        .task { editors = state.markdownEditors() }
        .alert("Couldn’t Save the Rule", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
        } message: {
            Text(error ?? "")
        }
    }

    /// "Visual Studio Code" from its bundle's file name.
    private static func name(_ app: URL) -> String { app.deletingPathExtension().lastPathComponent }

    // MARK: Rows

    private func group(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: Theme.Space.x6) {
            Text(title)
                .textStyle(Theme.Text.calloutBold)
                .foregroundStyle(Theme.Colors.secondaryLabel)
                .padding(.leading, Theme.Space.x4)
                .accessibilityAddTraits(.isHeader)
            VStack(alignment: .leading, spacing: 0) { content() }
                .surface(Theme.Colors.background, .fileChip, in: RoundedRectangle(cornerRadius: Theme.Radius.box))
        }
    }

    private var separator: some View {
        Rectangle().fill(Theme.Colors.separatorLight).frame(height: Theme.Size.hairline)
    }

    private func toggle(_ label: String, _ note: String, _ isOn: Binding<Bool>) -> some View {
        settingsRow(label, note) {
            Toggle(label, isOn: isOn).toggleStyle(DesignSwitchStyle(offFill: Theme.Colors.settingsSwitchOff)).labelsHidden()
        }
    }

    private func smallButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .textStyle(Theme.Text.callout)
                .foregroundStyle(Theme.Colors.label)
                .padding(.horizontal, Theme.Space.x10)
                .frame(height: Theme.Size.buttonMini)
                .surface(Theme.Colors.background, .settingsButton, in: RoundedRectangle(cornerRadius: Theme.Radius.code))
                .contentShape(RoundedRectangle(cornerRadius: Theme.Radius.code))
        }
        .buttonStyle(.plain)
    }

    // MARK: Project

    @ViewBuilder
    private func context(of project: Project) -> some View {
        let isReading = state.readingContext.contains(project.id)
        settingsRow("What Mel knows about this project", knows(project, isReading: isReading)) {
            if project.hasContext { smallButton("Show Files") { state.showContext(of: project) } }
            smallButton(project.hasContext ? "Read Again" : "Read Now") { Task { await state.readContext(of: project) } }
                .disabled(isReading || !state.agent.isReady)
                .opacity(isReading || !state.agent.isReady ? 0.5 : 1)
        }
        separator
        VStack(alignment: .leading, spacing: Theme.Space.x8) {
            Text("Rules every agent follows").textStyle(Theme.Text.body)
            Text("Saved in principles.md. Every spec and every task reads them first.")
                .textStyle(Theme.Text.captionLoose)
                .foregroundStyle(Theme.Colors.secondaryLabel)
            ForEach(state.contexts[project.id]?.rules ?? [], id: \.self) { rule in
                HStack(alignment: .top, spacing: Theme.Space.x8) {
                    Text(rule).textStyle(Theme.Text.calloutLoose).frame(maxWidth: .infinity, alignment: .leading)
                    Button {
                        do { try state.removeRule(rule, from: project) } catch { self.error = error.localizedDescription }
                    } label: {
                        DesignIcon(glyph: .close, size: Theme.Size.readyCheck, weight: 2)
                            .foregroundStyle(Theme.Colors.secondaryLabel)
                            .frame(width: Theme.Size.ruleRemove, height: Theme.Size.ruleRemove)
                            .contentShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Remove rule: \(rule)")
                }
                .padding(.vertical, Theme.Space.x6)
                .padding(.horizontal, Theme.Space.x8)
                .background(Theme.Colors.fill, in: RoundedRectangle(cornerRadius: Theme.Radius.code))
            }
            if let text = Binding($newRule) {
                TextField("A rule in one sentence", text: text)
                    .textFieldStyle(.plain)
                    .textStyle(Theme.Text.calloutLoose)
                    .focused($isAddingRule)
                    .padding(.vertical, Theme.Space.x6)
                    .padding(.horizontal, Theme.Space.x8)
                    .surface(Theme.Colors.background, .focus, in: RoundedRectangle(cornerRadius: Theme.Radius.code))
                    .onSubmit { addRule(to: project) }
                    .onExitCommand { newRule = nil }
                    .accessibilityLabel("New rule")
            }
            smallButton(newRule == nil ? "Add Rule" : "Save Rule") {
                if newRule == nil {
                    newRule = ""
                    isAddingRule = true
                } else {
                    addRule(to: project)
                }
            }
        }
        .padding(EdgeInsets(top: Theme.Space.x10, leading: Theme.Space.x12, bottom: Theme.Space.x12, trailing: Theme.Space.x12))
    }

    private func knows(_ project: Project, isReading: Bool) -> String {
        if isReading { return "Reading the project now, about a minute. Nothing waits for it." }
        if let error = state.contextErrors[project.id] { return error }
        return project.hasContext ? "product, tech, structure · in .mel/project/" : "Not read yet. Mel reads it once, in the background."
    }

    private func addRule(to project: Project) {
        let rule = (newRule ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        newRule = nil
        guard !rule.isEmpty else { return }
        do { try state.addRule(rule, to: project) } catch { self.error = error.localizedDescription }
    }
}

#Preview("Project read") {
    SpecsSettings().environment(PreviewData.appState([], contexts: [PreviewData.project.id: PreviewData.context]))
}

#Preview("Reading the project") {
    SpecsSettings().environment(PreviewData.appState([], projects: [PreviewData.habitTracker], readingContext: [PreviewData.habitTracker.id]))
}

#Preview("Not read yet") {
    SpecsSettings().environment(PreviewData.appState([], projects: [PreviewData.habitTracker]))
}

#Preview("No project") {
    SpecsSettings().environment(PreviewData.appState([], projects: []))
}
