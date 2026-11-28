import Foundation
import Observation
import Synchronization
import MelAgent
import MelSpec
import MelStorage
import MelSystem

@Observable final class AppState {
    var agent: AgentStatus = .checking
    var extraSearchPaths: [String] {
        didSet { defaults.set(extraSearchPaths, forKey: Self.searchPathsKey) }
    }
    /// Settings › Specs: the language new specs are written in.
    var specLanguage: SpecLanguage {
        didSet { defaults.set(specLanguage.rawValue, forKey: Self.specLanguageKey) }
    }
    /// Settings › Agents › Models for each step (10.4). Building is Sonnet by default: a task has a clear
    /// scope, where Sonnet comes close to Opus at half the price (research 2026-11-27).
    var models: [ModelStep: AgentModel] {
        didSet { for (step, model) in models where oldValue[step] != model { defaults.set(model.rawValue, forKey: Self.modelKey(step)) } }
    }

    func model(for step: ModelStep) -> AgentModel { models[step] ?? step.defaultModel }
    /// Every spec of every project, found by scanning `specs/*/.mel/state.json`.
    var specs: [Spec] = []
    /// Library projects whose folder is gone; row title = folder name.
    var missingFolders: [URL] = []
    var projects: [Project] = []
    /// The project the sidebar shows; nil means the first one.
    var projectID: Project.ID? {
        didSet { defaults.set(projectID?.path(percentEncoded: false), forKey: Self.currentProjectKey) }
    }
    private(set) var contexts: [Project.ID: ProjectContext] = [:]
    /// Projects whose context is being read in the background, and why the last read of one failed.
    private(set) var readingContext: Set<Project.ID> = []
    private(set) var contextErrors: [Project.ID: String] = [:]
    /// Each project's current git branch, read from `.git/HEAD` at load.
    private(set) var branches: [Project.ID: String] = [:]
    /// V2-0: git repos one level under `~/Developer`.
    private(set) var foundRepositories: [FoundRepository] = []
    /// GH-1: the user's GitHub account through their GitHub CLI (OQ #44).
    var github: GitHubAccount = .checking
    /// GH-1 On GitHub, newest first; loaded once signed in.
    private(set) var githubRepos: [GitHubRepo] = []
    /// While `gh repo list` runs: Refresh shows a spinner.
    private(set) var loadingGitHubRepos = false
    /// Each project's GitHub repo, `owner/name` from its `origin`; nil when it has none.
    private(set) var remotes: [Project.ID: String] = [:]
    /// Settings › Specs › Open files in: the app for Open in Editor; nil is the Mac's default for Markdown.
    var editor: URL? {
        didSet { defaults.set(editor?.path(percentEncoded: false), forKey: Self.editorKey) }
    }
    var selection: Spec.ID?
    var runningSpecID: Spec.ID?

    /// Notifications; tests replace both.
    @ObservationIgnored var notify: (_ title: String, _ body: String, _ at: Date?) -> Void = { Notifier.post(title: $0, body: $1, at: $2) }
    @ObservationIgnored var authorizeNotifications: () async -> Void = { await Notifier.requestAuthorization() }
    /// V2-3 Check it: a task's verify command in the project folder. Tests replace it.
    @ObservationIgnored var runCheck: @Sendable (_ command: String, _ folder: URL) async -> Check.Result = { await Check.run($0, in: $1) }
    @ObservationIgnored private var askedForNotifications = false
    /// Found by `scanGitHub`; tests set a fake script.
    @ObservationIgnored var gitHubCLI: GitHubCLI?
    @ObservationIgnored private var signingIn: Task<Void, Never>?
    /// V2-0's scan folder and the parent of a project made from an idea; tests replace it.
    @ObservationIgnored var developerFolder = FileManager.default.homeDirectoryForCurrentUser.appending(path: "Developer", directoryHint: .isDirectory)

    @ObservationIgnored private let adapter: any AgentAdapter
    @ObservationIgnored private let makeRunner: @Sendable (URL) -> any AgentRunning
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let library: Library
    @ObservationIgnored private var sessions: [Spec.ID: SpecSession] = [:]
    @ObservationIgnored private var runner: (executable: URL, runner: any AgentRunning)?
    @ObservationIgnored private var isPreview = false
    /// Projects made by `createSpec` this launch; intake's name renames their folder.
    @ObservationIgnored private var ideaProjects: Set<Project.ID> = []
    private static let searchPathsKey = "extraSearchPaths"
    private static let specLanguageKey = "specLanguage"
    private static func modelKey(_ step: ModelStep) -> String { "model." + step.rawValue }
    /// Before 0.12: one model for the conversation's runs, one for questions and checks, one for building.
    private static func oldModelKey(_ step: ModelStep) -> String {
        switch step {
        case .questions, .checks: "quickModel"
        case .building: "buildModel"
        case .productFiles, .architecture, .tasks, .changes: "writingModel"
        }
    }
    private static let currentProjectKey = "currentProject"
    private static let editorKey = "editorApp"

    /// Composition root passes `ClaudeCode()` and `{ AgentRunner(adapter: ClaudeCode(), executable: $0) }`;
    /// tests and previews pass fakes. Restores the project library and scans each project's specs.
    init(adapter: any AgentAdapter, makeRunner: @escaping @Sendable (URL) -> any AgentRunning, defaults: UserDefaults = .standard) {
        self.adapter = adapter
        self.makeRunner = makeRunner
        self.defaults = defaults
        library = Library(defaults: defaults, key: "projects")
        extraSearchPaths = defaults.stringArray(forKey: Self.searchPathsKey) ?? []
        specLanguage = defaults.string(forKey: Self.specLanguageKey).flatMap(SpecLanguage.init) ?? .english
        models = Dictionary(uniqueKeysWithValues: ModelStep.allCases.map { step in
            (step, (defaults.string(forKey: Self.modelKey(step)) ?? defaults.string(forKey: Self.oldModelKey(step))).flatMap(AgentModel.init) ?? step.defaultModel)
        })
        projectID = defaults.string(forKey: Self.currentProjectKey).map { URL(filePath: $0).normalizedFolder }
        editor = defaults.string(forKey: Self.editorKey).map { URL(filePath: $0) }
        for item in library.load() {
            if item.isMissing {
                missingFolders.append(item.folder)
            } else {
                load(item.folder)
            }
        }
    }

    func scanForAgent() async {
        agent = .checking
        agent = await adapter.detect(extraPaths: extraSearchPaths)
    }

    func session(for id: Spec.ID) -> SpecSession {
        if let session = sessions[id] { return session }
        guard let spec = specs.first(where: { $0.id == id }) else { fatalError("unknown spec \(id)") }
        let session = isPreview ? .preview(spec) : SpecSession(spec: spec, app: self)
        sessions[id] = session
        return session
    }

    // MARK: - Projects

    func specs(in project: Project) -> [Spec] { specs.filter { $0.project == project.folder } }

    var currentProject: Project? { projects.first { $0.id == projectID } ?? projects.first }

    /// V2-0: git repos in `~/Developer`, read off the main actor.
    func findRepositories() async {
        let folder = developerFolder
        let found = await Task.detached { Git.repositories(in: folder) }.value
        foundRepositories = found.map { FoundRepository(url: $0.url, language: $0.language, modified: $0.modified) }
    }

    /// Adds a folder to the library and scans its specs.
    @discardableResult
    func addProject(_ folder: URL) throws -> Project {
        let project = Project(folder: folder)
        if let existing = projects.first(where: { $0.id == project.id }) { return existing }
        guard FileManager.default.fileExists(atPath: project.folder.path) else { throw CocoaError(.fileNoSuchFile) }
        let added = load(project.folder)
        saveLibrary()
        return added
    }

    /// V2-0 Start with a repo (also the sidebar's Add Project…): it becomes the current project and
    /// Mel reads it once in the background. No screen waits for that.
    @discardableResult
    func startProject(_ folder: URL) throws -> Project {
        let project = try addProject(folder)
        projectID = project.id
        if !project.hasContext { Task { await readContext(of: project) } }
        return project
    }

    /// Start from an idea: creates `<parent>/<slug>/` as a new project.
    @discardableResult
    func createProject(name: String, parent: URL) throws -> Project {
        try addProject(ProjectStore.createProject(name: name, parent: parent))
    }

    func removeProject(_ project: Project) {
        for spec in specs(in: project) { sessions[spec.id] = nil }
        specs.removeAll { $0.project == project.folder }
        if let selection, !specs.contains(where: { $0.id == selection }) { self.selection = nil }
        projects.removeAll { $0.id == project.id }
        contexts[project.id] = nil
        contextErrors[project.id] = nil
        branches[project.id] = nil
        remotes[project.id] = nil
        if projectID == project.id { projectID = nil }
        saveLibrary()
    }

    /// One read-only run over the repo; Mel writes the four files in `.mel/project/`. Runs next to
    /// a spec's own runs: after Start on V2-0, and from Settings › Specs › Read Again.
    func readContext(of project: Project) async {
        guard !readingContext.contains(project.id) else { return }
        contextErrors[project.id] = nil
        let folder = project.folder
        guard !ProjectStore.isEmpty(project: folder) else { contextErrors[project.id] = "There is no code in this folder yet."; return }
        guard let runner = agentRunner() else { contextErrors[project.id] = "Claude Code isn't ready."; return }
        readingContext.insert(project.id)
        defer { readingContext.remove(project.id) }
        let mode = "Read the code in this folder first: the README, the build files and the main source folders."
        // The first project spec comes from the same reading (OQ #45); once it exists Mel keeps it.
        let needsAreas = ProjectStore.readProjectSpec(project: folder) == nil
        let areas = needsAreas ? Self.areasRequest : ""
        // Reading and summing up the project: Haiku's job, at low effort (research 2026-11-27).
        let request = AgentRequest(prompt: Prompt.project.build(["mode": mode, "areas": areas]), workingDirectory: folder, persistSession: false, model: .haiku, effort: .low)
        var result: String?
        do {
            loop: for try await event in runner.run(request) {
                switch event {
                case .done(let text): result = text; break loop
                case .failed: break loop
                default: break
                }
            }
        } catch {}
        guard let result, let context = try? ProjectContext.decode(result) else {
            contextErrors[project.id] = "Claude Code's reply couldn't be read."
            return
        }
        do {
            try await Task.detached {
                try ProjectStore.writeContext(context, project: folder)
                if needsAreas, !context.areas.isEmpty {
                    try ProjectStore.writeProjectSpec(ProjectSpec.numbered(context.areas.map { ($0.file, $0.title, $0.rules) }), project: folder)
                }
            }.value
        } catch {
            contextErrors[project.id] = error.localizedDescription
            return
        }
        contexts[project.id] = context
        if let i = projects.firstIndex(where: { $0.id == project.id }) { projects[i].hasContext = true }
    }

    /// The project scan's extra ask when `specs/current/` doesn't exist yet (OQ #45).
    private static let areasRequest = """
        Also add `"areas"`: how the app works today for the people who use it, read from the code. One entry per area they see (3 to 10), each with at most 8 rules: `"areas":[{"file":"schedule.md","title":"Schedule","rules":["WHEN a member opens the schedule, THEN it shows classes for the next 7 days."]}]`. Each rule is one `WHEN …, THEN ….` sentence about behavior a user can see, only what the code does now. A library or tool without users: its public behavior. Nothing found: `"areas":[]`.
        """

    // MARK: Linear (V2-35, OQ #47)

    /// Whether a Linear key is in the Keychain; Send tasks asks for one the first time.
    private(set) var hasLinearKey = LinearKey.read() != nil

    var linearClient: LinearClient? { LinearKey.read().map(LinearClient.init) }

    /// The teams the key can see; a working key is saved, a wrong one is not.
    func linearTeams(key: String? = nil) async throws -> [LinearTeam] {
        guard let key = key ?? LinearKey.read() else { return [] }
        let teams = try await LinearClient(key: key).teams().map { LinearTeam(id: $0.id, name: $0.name, key: $0.key) }
        if key != LinearKey.read() {
            try LinearKey.save(key)
            hasLinearKey = true
        }
        return teams
    }

    func forgetLinearKey() {
        LinearKey.delete()
        hasLinearKey = false
    }

    /// Settings › Specs "Add Rule" and a rule's remove button.
    func addRule(_ rule: String, to project: Project) throws {
        try ProjectStore.addRule(rule, project: project.folder)
        contexts[project.id] = ProjectStore.readContext(project: project.folder)
        if let i = projects.firstIndex(where: { $0.id == project.id }) { projects[i].hasContext = true }
    }

    func removeRule(_ rule: String, from project: Project) throws {
        try ProjectStore.removeRule(rule, project: project.folder)
        contexts[project.id] = ProjectStore.readContext(project: project.folder)
    }

    /// Settings › Specs "How the app works today": the number of areas in `specs/current/`; nil without it.
    func projectSpecAreas(of project: Project) -> Int? { ProjectStore.readProjectSpec(project: project.folder)?.areas.count }

    func showProjectSpec(of project: Project) {
        SystemActions.showInFinder(ProjectStore.projectSpecFolder(project: project.folder))
    }

    /// Settings › Specs "Show Files": opens `.mel/project/` in Finder.
    func showContext(of project: Project) {
        SystemActions.showInFinder(ProjectStore.contextFolder(project: project.folder))
    }

    /// Settings › Specs › Open files in: the apps that open Markdown.
    func markdownEditors() -> [URL] { SystemActions.markdownEditors() }

    // MARK: - Specs

    /// V2-1 Start. Creates `specs/<slug>/` in `project` and copies attachments, then selects the spec;
    /// the board then calls `start()` on the session. Without a project (New product only) a new
    /// project folder is made under `parent`, by default `~/Developer` (created if missing), and
    /// becomes the current project. Name it `Spec.untitledName` to let intake name it.
    func createSpec(name: String, idea: String, size: SpecSize, project: Project?, parent: URL? = nil, fillGaps: Bool = true, files: [URL] = [], logs: [String] = []) throws -> SpecSession {
        let isNew = project == nil
        let project = try project ?? createProject(name: name, parent: parent ?? developerFolder)
        if isNew {
            ideaProjects.insert(project.id)
            projectID = project.id
        }
        let folder = SpecStore.freeFolder(name: name, in: project.folder.appending(path: "specs", directoryHint: .isDirectory))
        let spec = Spec(name: name, idea: idea, size: size, folder: folder, fillGaps: fillGaps, language: specLanguage)
        try SpecStore.create(spec)
        specs.append(spec)
        selection = spec.id
        let session = session(for: spec.id)
        if !files.isEmpty || !logs.isEmpty {
            Task {
                do {
                    try await session.attach(files)
                    for log in logs { try await session.attachLog(log) }
                } catch {}
            }
        }
        return session
    }

    /// Intake's name for an untitled spec: renames its folder, and the project folder too when
    /// it was made for this spec this launch. Returns the spec's new folder.
    func rename(_ id: Spec.ID, to name: String) throws -> URL {
        guard let i = specs.firstIndex(where: { $0.id == id }) else { throw CocoaError(.fileNoSuchFile) }
        let old = Project(folder: specs[i].project)
        var project = old
        if ideaProjects.contains(old.id), specs(in: old).count == 1, let p = projects.firstIndex(where: { $0.id == old.id }) {
            let folder = SpecStore.freeFolder(name: name, in: old.folder.deletingLastPathComponent())
            try FileManager.default.moveItem(at: old.folder, to: folder)
            projects[p].folder = folder.normalizedFolder
            project = projects[p]
            ideaProjects.remove(old.id)
            ideaProjects.insert(project.id)
            contexts[project.id] = contexts.removeValue(forKey: old.id)
            branches[project.id] = branches.removeValue(forKey: old.id)
            remotes[project.id] = remotes.removeValue(forKey: old.id)
            if projectID == old.id { projectID = project.id }
            saveLibrary()
        }
        let current = SpecStore.specFolder(slug: specs[i].folder.lastPathComponent, project: project.folder)
        let folder = SpecStore.freeFolder(name: name, in: current.deletingLastPathComponent())
        try FileManager.default.moveItem(at: current, to: folder)
        specs[i].name = name
        specs[i].folder = folder
        return folder
    }

    /// Hides the spec until the next launch; its files stay.
    func removeFromLibrary(_ id: Spec.ID) {
        specs.removeAll { $0.id == id }
        sessions[id] = nil
        if selection == id { selection = nil }
    }

    /// "Locate…": `folder` is the moved project.
    func locate(_ missing: URL, at folder: URL) throws {
        missingFolders.removeAll { $0 == missing }
        let project = try addProject(folder)
        saveLibrary()
        projectID = project.id
    }

    /// Moves the whole project folder, code included, to the Trash and drops it from the list.
    func trashProject(_ project: Project) async throws {
        let folder = project.folder
        try await Task.detached { try FileManager.default.trashItem(at: folder, resultingItemURL: nil) }.value
        removeProject(project)
    }

    func removeMissing(_ missing: URL) {
        missingFolders.removeAll { $0 == missing }
        saveLibrary()
    }

    // MARK: - GitHub (OQ #44, GH-1 to GH-3)

    /// Looks for `gh` and its account; signed in, loads the repos for Start.
    func scanGitHub() async {
        guard let executable = GitHubCLI.locate(extraPaths: extraSearchPaths) else {
            gitHubCLI = nil
            github = .missing
            return
        }
        let cli = GitHubCLI(executable: executable)
        gitHubCLI = cli
        if case .signingIn = github { return }
        if let login = await Task.detached(operation: { cli.login() }).value {
            github = .signedIn(login)
            await loadGitHubRepos()
        } else {
            github = .signedOut
        }
    }

    /// Also Refresh on Start and in the repo choice: the list again, newest first.
    func loadGitHubRepos() async {
        guard let cli = gitHubCLI, !loadingGitHubRepos else { return }
        loadingGitHubRepos = true
        defer { loadingGitHubRepos = false }
        guard let json = try? await Task.detached(operation: { try cli.repos() }).value else { return }
        githubRepos = (try? GitHubRepo.list(json: json)) ?? []
    }

    /// GH-1b: `gh auth login --web`; the code shows on Start and GitHub opens in the browser.
    func signInToGitHub() {
        guard let cli = gitHubCLI else { return }
        github = .signingIn(code: nil)
        signingIn = Task {
            let opened = Mutex(false)
            let done = await cli.signIn { output in
                guard let code = gitHubDeviceCode(in: output) else { return }
                let first = opened.withLock { was in defer { was = true }; return !was }
                Task { @MainActor in
                    self.github = .signingIn(code: code)
                    if first { SystemActions.open(URL(string: "https://github.com/login/device")!) }
                }
            }
            guard !Task.isCancelled else { return }
            github = .checking
            if done { await scanGitHub() } else { github = .signedOut }
        }
    }

    func cancelGitHubSignIn() {
        signingIn?.cancel()
        signingIn = nil
        github = .signedOut
    }

    /// GH-1 Clone and Start, GH-2 a repo you already made: cloned into `~/Developer/<name>`, then added like any project.
    @discardableResult
    func cloneProject(_ repo: GitHubRepo) async throws -> Project {
        guard let cli = gitHubCLI else { throw CocoaError(.featureUnsupported) }
        let folder = developerFolder.appending(path: repo.name, directoryHint: .isDirectory)
        guard !FileManager.default.fileExists(atPath: folder.path) else {
            throw CocoaError(.fileWriteFileExists, userInfo: [NSLocalizedDescriptionKey: "~/Developer/\(repo.name) already exists. Drop that folder on the window to use it."])
        }
        let (name, parent) = (repo.nameWithOwner, developerFolder)
        try await Task.detached {
            try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true)
            try cli.clone(name, to: folder)
        }.value
        return try startProject(folder)
    }

    /// GH-2 / GH-3 a new repo for `project`, made `origin`; what is committed is pushed.
    func createRepo(for project: Project, name: String, isPrivate: Bool) async throws {
        guard let cli = gitHubCLI else { throw CocoaError(.featureUnsupported) }
        let folder = project.folder
        remotes[project.id] = try await Task.detached { try cli.create(name: name, isPrivate: isPrivate, from: folder) }.value
        branches[project.id] = Git.branch(at: folder)
    }

    /// GH-3 an empty repo the user made, made `project`'s `origin`.
    func connectRepo(_ repo: GitHubRepo, to project: Project) async throws {
        guard let cli = gitHubCLI else { throw CocoaError(.featureUnsupported) }
        let (folder, url) = (project.folder, repo.url)
        try await Task.detached { try cli.connect(url, to: folder) }.value
        remotes[project.id] = repo.nameWithOwner
        branches[project.id] = Git.branch(at: folder)
    }

    func openOnGitHub(_ project: Project) {
        guard let name = remotes[project.id], let url = URL(string: "https://github.com/\(name)") else { return }
        SystemActions.open(url)
    }

    // System actions for views (views never import MelSystem)
    func signIn() {
        let executable: URL
        switch agent {
        case .ready(let url, _), .notSignedIn(let url): executable = url
        default: return
        }
        try? SystemActions.openInTerminal(command: adapter.loginCommand(executable: executable), in: FileManager.default.homeDirectoryForCurrentUser)
    }

    func copy(_ text: String) { SystemActions.copy(text) }

    // MARK: - For SpecSession

    /// One spec runs at a time across the app. Reading a project's context doesn't count.
    var isAgentBusy: Bool { runningSpecID != nil }

    /// Asks once per launch, without waiting: macOS drops posts until the user allows them.
    func requestNotificationsOnce() {
        guard !askedForNotifications else { return }
        askedForNotifications = true
        Task { await authorizeNotifications() }
    }

    /// The runner for the detected executable, or nil while Claude Code isn't ready. One per
    /// executable: it reads the login PATH once.
    func agentRunner() -> (any AgentRunning)? {
        guard case .ready(let executable, _) = agent else { return nil }
        if let runner, runner.executable == executable { return runner.runner }
        let made = makeRunner(executable)
        runner = (executable, made)
        return made
    }

    /// Keeps the sidebar in step with a session's spec.
    func update(_ spec: Spec) {
        guard let i = specs.firstIndex(where: { $0.id == spec.id }) else { return }
        specs[i] = spec
    }

    // MARK: - Library

    /// Adds the project with its context and specs.
    @discardableResult
    private func load(_ folder: URL) -> Project {
        let context = ProjectStore.readContext(project: folder)
        let project = Project(folder: folder, hasContext: context != nil)
        projects.append(project)
        contexts[project.id] = context
        branches[project.id] = Git.branch(at: folder)
        remotes[project.id] = Git.origin(at: folder).flatMap(gitHubName(remote:))
        for var spec in SpecStore.scan(project: project.folder) where !specs.contains(where: { $0.id == spec.id }) {
            // A board that was working when Mel quit waits for Resume: nothing runs on launch.
            if spec.halted == nil, let step = spec.nextStep { spec.halt(.user, during: step) }
            specs.append(spec)
        }
        return project
    }

    private func saveLibrary() {
        guard !isPreview else { return }
        library.save(projects.map(\.folder) + missingFolders)
    }

    static func preview(_ specs: [Spec], agent: AgentStatus, projects: [Project] = [], contexts: [Project.ID: ProjectContext] = [:], foundRepositories: [FoundRepository] = [], readingContext: Set<Project.ID> = [], branches: [Project.ID: String] = [:], sessions: [SpecSession] = [], github: GitHubAccount = .signedOut, githubRepos: [GitHubRepo] = [], remotes: [Project.ID: String] = [:]) -> AppState {
        let state = AppState(adapter: InertAdapter(), makeRunner: { _ in InertRunner() }, defaults: UserDefaults(suiteName: "preview")!)
        state.isPreview = true
        state.specs = specs
        state.agent = agent
        state.projects = projects
        state.contexts = contexts
        state.foundRepositories = foundRepositories
        state.readingContext = readingContext
        state.branches = branches
        state.github = github
        state.githubRepos = githubRepos
        state.remotes = remotes
        for session in sessions { state.sessions[session.spec.id] = session }   // fixtures with live text, activity, step
        state.selection = specs.first?.id
        return state
    }
}

/// Does nothing; backs `AppState.preview`.
private struct InertAdapter: AgentAdapter {
    func detect(extraPaths: [String]) async -> AgentStatus { .missing }
    func loginCommand(executable: URL) -> String { "" }
    func arguments(for request: AgentRequest) -> [String] { [] }
    func environment(path: String) -> [String: String] { [:] }
    func parse(line: Substring) -> [AgentEvent] { [] }
}

private struct InertRunner: AgentRunning {
    func run(_ request: AgentRequest) -> AsyncThrowingStream<AgentEvent, Error> { AsyncThrowingStream { $0.finish() } }
    func stop() async {}
}

/// GH-1: where the user's GitHub account stands.
enum GitHubAccount: Equatable {
    case checking
    /// No GitHub CLI on this Mac (GH-1c).
    case missing
    case signedOut
    /// GH-1b: `code` once `gh` printed it.
    case signingIn(code: String?)
    case signedIn(String)

    var login: String? { if case .signedIn(let login) = self { login } else { nil } }
}
