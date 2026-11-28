import SwiftUI
import MelSpec

/// Send tasks (V2-35, OQ #47): one issue per task in GitHub Issues (through `gh`) or Linear (its API
/// key, asked the first time, kept in the Keychain). Tasks already sent are skipped. No tokens.
struct SendTasksSheet: View {
    let session: SpecSession
    let close: () -> Void

    @Environment(AppState.self) private var state
    @State private var target: SpecSession.SendTarget = .github
    @State private var checklist = true
    @State private var milestones = true
    @State private var teams: [LinearTeam] = []
    @State private var team: LinearTeam?
    @State private var key = ""
    @State private var isLoading = false
    @State private var keyError: String?

    private var spec: Spec { session.spec }
    private var repo: String? { session.gitHubRepo }
    private var drafts: [IssueDraft] { session.issueDrafts(checklist: checklist, milestones: milestones && target == .github) }
    private var newCount: Int { drafts.count { spec.issues?[$0.task] == nil } }
    private var ready: Bool { target == .github ? repo != nil && state.gitHubCLI != nil : team != nil }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: Theme.Space.x12) {
                VStack(alignment: .leading, spacing: 1) {
                    Text("Send tasks").textStyle(Theme.Text.headline).accessibilityAddTraits(.isHeader)
                    Text("One issue per task, so the team can follow the plan where they already work.")
                        .textStyle(Theme.Text.callout).foregroundStyle(Theme.Colors.secondaryLabel)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Button(action: close) {
                    DesignIcon(glyph: .close, size: 10, weight: 2.2)
                        .foregroundStyle(Theme.Colors.bodyLabel)
                        .frame(width: 28, height: 28)
                        .background(Theme.Colors.chipFill, in: Circle())
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.cancelAction)
                .accessibilityLabel("Close")
            }
            .padding(EdgeInsets(top: 18, leading: Theme.Space.x20, bottom: Theme.Space.x14, trailing: Theme.Space.x16))
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Space.x14) {
                    destinations
                    settings
                    preview
                    if let result = session.sendResult {
                        HStack(spacing: Theme.Space.x8) {
                            DoneMark(size: 16)
                            Text(result + ". The numbers are saved with the spec, so these tasks aren’t sent again.")
                                .textStyle(Theme.Text.calloutLoose).fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    if let error = session.lastError {
                        Text(error).textStyle(Theme.Text.calloutLoose).foregroundStyle(Theme.Colors.cautionText)
                    }
                }
                .padding(EdgeInsets(top: 0, leading: Theme.Space.x20, bottom: Theme.Space.x16, trailing: Theme.Space.x20))
            }
            HStack(spacing: Theme.Space.x8) {
                Text(target == .github ? "Uses the gh command on this Mac\(state.github.login.map { ", signed in as \($0)" } ?? ""). No tokens." : "Uses your Linear key from the Keychain. No tokens.")
                    .textStyle(Theme.Text.captionLoose)
                    .foregroundStyle(Theme.Colors.secondaryLabel)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if session.isSending { ProgressView().controlSize(.small) }
                Button(newCount == 0 ? "Done" : "Cancel", action: close).buttonStyle(PanelButtonStyle())
                if newCount > 0 {
                    Button("Create \(newCount) \(newCount == 1 ? "issue" : "issues")") {
                        Task { await session.sendTasks(to: target, team: team, checklist: checklist, milestones: milestones) }
                    }
                    .buttonStyle(PanelButtonStyle(primary: true))
                    .disabled(!ready || session.isSending)
                    .keyboardShortcut(.defaultAction)
                }
            }
            .padding(EdgeInsets(top: Theme.Space.x12, leading: Theme.Space.x20, bottom: Theme.Space.x12, trailing: Theme.Space.x16))
            .background(Theme.Colors.fillSubtle)
            .overlay(alignment: .top) { Rectangle().fill(Theme.Colors.separatorLight).frame(height: 0.5) }
        }
        .frame(width: Theme.Size.sendSheetWidth)
        .frame(maxHeight: Theme.Size.tellPanelHeight)
        .background(Theme.Colors.background)
        .foregroundStyle(Theme.Colors.label)
        .onAppear { if repo == nil { target = .linear } }
        .task(id: target) { if target == .linear, state.hasLinearKey, teams.isEmpty { await loadTeams(key: nil) } }
    }

    private var destinations: some View {
        HStack(spacing: Theme.Space.x2) {
            segment("GitHub Issues", .github)
            segment("Linear", .linear)
        }
        .padding(Theme.Space.x2)
        .frame(height: 30)
        .background(Theme.Colors.badgeFill, in: Capsule())
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Where to")
    }

    private func segment(_ label: String, _ value: SpecSession.SendTarget) -> some View {
        Button(label) { target = value }
            .buttonStyle(BoardSegmentStyle(isSelected: target == value, text: target == value ? Theme.Text.calloutBold : Theme.Text.callout))
    }

    private var settings: some View {
        VStack(spacing: 0) {
            HStack(spacing: Theme.Space.x10) {
                Text(target == .github ? "Repository" : "Team").textStyle(Theme.Text.body).fixedSize().frame(maxWidth: .infinity, alignment: .leading)
                destination
            }
            .padding(.vertical, Theme.Space.x6)
            .padding(.horizontal, Theme.Space.x12)
            .frame(minHeight: Theme.Size.tellBar)
            Rectangle().fill(Theme.Colors.separator).frame(height: 0.5).padding(.leading, Theme.Space.x12)
            toggleRow("Criteria as a checklist", "Each issue lists the WHEN/THEN criteria its task covers.", $checklist)
            if target == .github {
                Rectangle().fill(Theme.Colors.separatorLight).frame(height: 0.5).padding(.leading, Theme.Space.x12)
                toggleRow("Phases as milestones", "The phases of TASKS.md.", $milestones)
            }
        }
        .background(Theme.Colors.freeAnswerFill, in: RoundedRectangle(cornerRadius: Theme.Radius.card))
    }

    @ViewBuilder
    private var destination: some View {
        if target == .github {
            Text(repo ?? "Connect the project to GitHub from its menu first")
                .textStyle(repo == nil ? Theme.Text.callout : Theme.Text.code)
                .foregroundStyle(repo == nil ? Theme.Colors.secondaryLabel : Theme.Colors.bodyLabel)
        } else if !teams.isEmpty {
            Picker("Team", selection: $team) {
                ForEach(teams, id: \.id) { Text("\($0.name) (\($0.key))").tag(Optional($0)) }
            }
            .labelsHidden()
            .fixedSize()
        } else if isLoading {
            ProgressView().controlSize(.small)
        } else {
            HStack(spacing: Theme.Space.x6) {
                SecureField("Linear API key", text: $key)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 200)
                    .onSubmit { Task { await loadTeams(key: key) } }
                Button("Connect") { Task { await loadTeams(key: key) } }
                    .buttonStyle(PanelButtonStyle())
                    .fixedSize()
                    .disabled(key.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .help("Linear › Settings › Security & access › Personal API keys. Kept in your Keychain.")
        }
    }

    private func toggleRow(_ title: String, _ note: String, _ value: Binding<Bool>) -> some View {
        HStack(spacing: Theme.Space.x12) {
            VStack(alignment: .leading, spacing: 0) {
                Text(title).textStyle(Theme.Text.body)
                Text(note).textStyle(Theme.Text.caption).foregroundStyle(Theme.Colors.secondaryLabel)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Toggle(title, isOn: value).labelsHidden().toggleStyle(.switch).controlSize(.small)
        }
        .padding(.vertical, Theme.Space.x6)
        .padding(.horizontal, Theme.Space.x12)
        .frame(minHeight: 52)
    }

    private var preview: some View {
        let sent = drafts.count - newCount
        return VStack(alignment: .leading, spacing: Theme.Space.x6) {
            Text("\(newCount) new \(newCount == 1 ? "issue" : "issues")" + (sent > 0 ? " · \(sent) already sent" : ""))
                .textStyle(Theme.Text.calloutBold).foregroundStyle(Theme.Colors.secondaryLabel)
            if let keyError { Text(keyError).textStyle(Theme.Text.captionLoose).foregroundStyle(Theme.Colors.cautionText) }
            ForEach(drafts, id: \.task) { draft in
                let issue = spec.issues?[draft.task]
                HStack(spacing: Theme.Space.x10) {
                    Image(systemName: "smallcircle.filled.circle").font(.system(size: 13))
                        .foregroundStyle(issue == nil ? Theme.Colors.success : Theme.Colors.emptyGroup)
                    VStack(alignment: .leading, spacing: 0) {
                        Text(draft.title).textStyle(Theme.Text.bodyMedium).lineLimit(1)
                        Text(([draft.milestone.map { "Milestone: \($0)" }, "label \(IssueDraft.label(slug: session.slug))", checklist ? "criteria as a checklist" : nil] as [String?]).compactMap(\.self).joined(separator: " · "))
                            .textStyle(Theme.Text.caption).foregroundStyle(Theme.Colors.secondaryLabel).lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    Text(issue.map { "Already sent · \($0)" } ?? "New").textStyle(Theme.Text.caption).foregroundStyle(Theme.Colors.secondaryLabel)
                }
                .padding(.vertical, Theme.Space.x6)
                .padding(.horizontal, Theme.Space.x12)
                .frame(minHeight: Theme.Size.tellBar)
                .surface(.clear, .outlineReplaced, in: RoundedRectangle(cornerRadius: Theme.Radius.box))
                .opacity(issue == nil ? 1 : 0.55)
            }
        }
    }

    private func loadTeams(key: String?) async {
        isLoading = true
        defer { isLoading = false }
        keyError = nil
        do {
            teams = try await state.linearTeams(key: key?.trimmingCharacters(in: .whitespaces))
            team = teams.first
        } catch {
            keyError = "Linear didn’t take the key: \(error.localizedDescription)"
        }
    }
}
