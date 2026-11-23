import SwiftUI
import MelSpec
import UniformTypeIdentifiers

/// A2 Pick a project (design/v2 Native-E2-PickFolder): drop zone, git repos found in ~/Developer, or start from an idea.
struct PickProjectView: View {
    @Environment(AppState.self) private var state
    @State var chosen: URL?
    @State private var isChoosing = false
    @State private var isTargeted = false
    @State private var error: String?
    let onBack: () -> Void
    let onRead: (Project) -> Void
    let onIdea: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.x22) {
            VStack(alignment: .leading, spacing: Theme.Space.x6) {
                Text("Step 2 of 2")
                    .textStyle(Theme.Text.captionBold)
                    .foregroundStyle(Theme.Colors.secondaryLabel)
                Text("Where does the work happen?")
                    .textStyle(Theme.Text.title1)
                    .foregroundStyle(Theme.Colors.label)
                    .accessibilityAddTraits(.isHeader)
                Text("Pick the repo you want specs for. Mel reads it once on this Mac. Code only leaves it through the coding agent you chose.")
                    .textStyle(Theme.Text.intro)
                    .foregroundStyle(Theme.Colors.bodyLabel)
            }

            dropZone

            if !state.foundRepositories.isEmpty {
                VStack(alignment: .leading, spacing: Theme.Space.x8) {
                    Text("Git repos Mel found in ~/Developer")
                        .textStyle(Theme.Text.bodyBold)
                        .foregroundStyle(Theme.Colors.label)
                        .padding(.horizontal, Theme.Space.x4)
                    VStack(spacing: 0) {
                        ForEach(state.foundRepositories) { repo in
                            Button { chosen = repo.url } label: {
                                HStack(spacing: Theme.Space.x10) {
                                    DesignIcon(glyph: .folder, size: Theme.Size.projectIcon)
                                        .foregroundStyle(Theme.Colors.secondaryLabel)
                                    Text(repo.url.lastPathComponent)
                                        .textStyle(Theme.Text.body)
                                        .foregroundStyle(Theme.Colors.label)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                    if let meta = Self.meta(repo) {
                                        Text(meta)
                                            .textStyle(Theme.Text.caption)
                                            .foregroundStyle(Theme.Colors.secondaryLabel)
                                    }
                                }
                                .padding(.horizontal, Theme.Space.x14)
                                .frame(minHeight: Theme.Size.repoRow)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityAddTraits(chosen == repo.url ? .isSelected : [])
                        }
                    }
                    .padding(.vertical, Theme.Space.x4)
                    .background(Theme.Colors.fill, in: RoundedRectangle(cornerRadius: Theme.Radius.card))
                }
            }

            HStack(spacing: Theme.Space.x12) {
                VStack(alignment: .leading, spacing: Theme.Space.x2) {
                    Text("No code yet?")
                        .textStyle(Theme.Text.bodyMedium)
                        .foregroundStyle(Theme.Colors.label)
                    Text("Start from an idea. Mel creates the folder and fills project context from your first spec.")
                        .textStyle(Theme.Text.callout)
                        .foregroundStyle(Theme.Colors.secondaryLabel)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Button("Start from an Idea", action: onIdea)
                    .buttonStyle(DesignButtonStyle(role: .secondary, height: Theme.Size.chip, leading: Theme.Space.x14, trailing: Theme.Space.x14, text: Theme.Text.body, elevation: .buttonSmall))
            }
            .padding(EdgeInsets(top: Theme.Space.x12, leading: Theme.Space.x14, bottom: Theme.Space.x12, trailing: Theme.Space.x14))
            .surface(.clear, .outlineList, in: RoundedRectangle(cornerRadius: Theme.Radius.card))

            HStack(spacing: Theme.Space.x12) {
                Button("Back", action: onBack).buttonStyle(DesignLinkStyle())
                Spacer()
                Button("Read This Repo", action: read)
                    .buttonStyle(DesignButtonStyle(leading: Theme.Space.x20, trailing: Theme.Space.x20))
                    .keyboardShortcut(.defaultAction)
                    .disabled(chosen == nil)
            }
        }
        .frame(maxWidth: Theme.Size.pickProjectWidth)
        .padding(EdgeInsets(top: Theme.Space.x16, leading: Theme.Space.x32, bottom: Theme.Space.x40, trailing: Theme.Space.x32))
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .setupChrome(title: "Set Up Project")
        .fileImporter(isPresented: $isChoosing, allowedContentTypes: [.folder]) { result in
            if case .success(let url) = result { chosen = url }
        }
        .alert("Couldn’t Add the Folder", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
        } message: {
            Text(error ?? "")
        }
        .task {
            if state.foundRepositories.isEmpty { await state.findRepositories() }
        }
    }

    private var dropZone: some View {
        Button { isChoosing = true } label: {
            VStack(spacing: Theme.Space.x6) {
                DesignIcon(glyph: .folderPlus, size: Theme.Size.dropIcon)
                    .foregroundStyle(Theme.Colors.accent)
                Text(chosen?.lastPathComponent ?? "Drop a project folder here")
                    .textStyle(Theme.Text.sectionTitle)
                    .foregroundStyle(Theme.Colors.label)
                Text(chosen.map { "\($0.path(percentEncoded: false).abbreviatingHome) · ready to read" } ?? "or click to choose one in Finder")
                    .textStyle(Theme.Text.callout)
                    .foregroundStyle(Theme.Colors.secondaryLabel)
            }
            .padding(Theme.Space.x24)
            .frame(maxWidth: .infinity, minHeight: Theme.Size.dropZone)
            .surface(
                chosen != nil || isTargeted ? Theme.Colors.accentTint : Theme.Colors.fillSubtle,
                chosen != nil || isTargeted ? .selected : .dropZone,
                in: RoundedRectangle(cornerRadius: Theme.Radius.large)
            )
            .contentShape(RoundedRectangle(cornerRadius: Theme.Radius.large))
        }
        .buttonStyle(.plain)
        .dropDestination(for: URL.self) { urls, _ in
            guard let url = urls.first(where: \.hasDirectoryPath) else { return false }
            chosen = url
            return true
        } isTargeted: { isTargeted = $0 }
        .accessibilityLabel(chosen.map { "Project folder \($0.lastPathComponent)" } ?? "Choose a project folder")
    }

    /// "Kotlin · edited today", "TypeScript · 3 months ago".
    static func meta(_ repo: FoundRepository, now: Date = .now) -> String? {
        let age = repo.modified.map { date in
            Calendar.current.isDate(date, inSameDayAs: now)
                ? "edited today"
                : RelativeDateTimeFormatter().localizedString(for: date, relativeTo: now)
        }
        let parts = [repo.language, age].compactMap(\.self)
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    private func read() {
        guard let chosen else { return }
        do { onRead(try state.addProject(chosen)) } catch { self.error = error.localizedDescription }
    }
}

#Preview("Nothing chosen") {
    PickProjectView(onBack: {}, onRead: { _ in }, onIdea: {})
        .environment(PreviewData.appState([], projects: [], foundRepositories: PreviewData.repositories))
        .frame(width: Theme.Size.windowWidth, height: Theme.Size.windowHeight - Theme.Size.toolbar)
}

#Preview("Folder chosen") {
    PickProjectView(chosen: PreviewData.repositories[0].url, onBack: {}, onRead: { _ in }, onIdea: {})
        .environment(PreviewData.appState([], projects: [], foundRepositories: PreviewData.repositories))
        .frame(width: Theme.Size.windowWidth, height: Theme.Size.windowHeight - Theme.Size.toolbar)
}
