import Foundation
import Observation
import MelAgent
import MelSpec
import MelStorage
import MelSystem

@Observable final class AppState {
    var agent: AgentStatus = .checking
    var extraSearchPaths: [String] {
        didSet { defaults.set(extraSearchPaths, forKey: Self.searchPathsKey) }
    }
    /// A1 and Settings: the language new specs are written in.
    var specLanguage: SpecLanguage {
        didSet { defaults.set(specLanguage.rawValue, forKey: Self.specLanguageKey) }
    }
    /// Every spec of every project, found by scanning `specs/*/.mel/state.json`.
    var specs: [Spec] = []
    /// Library projects whose folder is gone; row title = folder name.
    var missingFolders: [URL] = []
    var projects: [Project] = []
    private(set) var contexts: [Project.ID: ProjectContext] = [:]
    /// Each project's current git branch, read from `.git/HEAD` at load and by A3.
    private(set) var branches: [Project.ID: String] = [:]
    /// A2: git repos one level under `~/Developer`.
    private(set) var foundRepositories: [FoundRepository] = []
    /// A3: the project-context run, while it's on screen.
    private(set) var projectSetup: ProjectSetup?
    var selection: Spec.ID?
    var runningSpecID: Spec.ID?

    /// Notifications; tests replace both.
    @ObservationIgnored var notify: (_ title: String, _ body: String, _ at: Date?) -> Void = { Notifier.post(title: $0, body: $1, at: $2) }
    @ObservationIgnored var authorizeNotifications: () async -> Void = { await Notifier.requestAuthorization() }
    @ObservationIgnored private var askedForNotifications = false
    /// A2's scan folder and the parent of a project made from an idea; tests replace it.
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

    /// Composition root passes `ClaudeCode()` and `{ AgentRunner(adapter: ClaudeCode(), executable: $0) }`;
    /// tests and previews pass fakes. Restores the project library and scans each project's specs.
    init(adapter: any AgentAdapter, makeRunner: @escaping @Sendable (URL) -> any AgentRunning, defaults: UserDefaults = .standard) {
        self.adapter = adapter
        self.makeRunner = makeRunner
        self.defaults = defaults
        library = Library(defaults: defaults, key: "projects")
        extraSearchPaths = defaults.stringArray(forKey: Self.searchPathsKey) ?? []
        specLanguage = defaults.string(forKey: Self.specLanguageKey).flatMap(SpecLanguage.init) ?? .english
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

    /// A2: git repos in `~/Developer`, read off the main actor.
    func findRepositories() async {
        let folder = developerFolder
        let found = await Task.detached { Git.repositories(in: folder) }.value
        foundRepositories = found.map { FoundRepository(url: $0.url, language: $0.language, modified: $0.modified) }
    }

    /// A2 "Choose Folder" or a found repo. Adds it to the library and scans its specs.
    @discardableResult
    func addProject(_ folder: URL) throws -> Project {
        let project = Project(folder: folder)
        if let existing = projects.first(where: { $0.id == project.id }) { return existing }
        guard FileManager.default.fileExists(atPath: project.folder.path) else { throw CocoaError(.fileNoSuchFile) }
        let added = load(project.folder)
        saveLibrary()
        return added
    }

    /// Start from an Idea: creates `<parent>/<slug>/` as a new project.
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
        branches[project.id] = nil
        saveLibrary()
    }

    /// A3: one read-only run over the repo; Mel writes the four files.
    func setUpProject(_ project: Project) async {
        let isNew = ProjectStore.isEmpty(project: project.folder)
        projectSetup = ProjectSetup(project: project, isNewProject: isNew, isRunning: true, activity: [], context: nil, lastError: nil)
        let folder = project.folder
        let (branch, fileCount) = await Task.detached { (Git.branch(at: folder), Git.fileCount(at: folder)) }.value
        projectSetup?.branch = branch
        branches[project.id] = branch
        projectSetup?.fileCount = fileCount
        func fail(_ message: String) {
            projectSetup?.isRunning = false
            projectSetup?.lastError = message
        }
        guard runningSpecID == nil, let runner = agentRunner() else { return fail("Claude Code isn't ready, or a spec is running.") }
        let mode = isNew
            ? "The folder `\(project.name)` is a new project with no code yet. Write short starting files from its name; the user will fill them in."
            : "Read the code in this folder first: the README, the build files and the main source folders."
        let request = AgentRequest(prompt: Prompt.project.build(["mode": mode]), workingDirectory: folder, persistSession: false)
        var result: String?
        do {
            loop: for try await event in runner.run(request) {
                switch event {
                case .step(let step): projectSetup?.activity.append(ActivityLine(at: .now, text: step))
                case .done(let text): result = text; break loop
                case .failed: break loop
                default: break
                }
            }
        } catch {}
        guard let result, let context = try? ProjectContext.decode(result) else { return fail("Claude Code's reply couldn't be read.") }
        do {
            try await Task.detached { try ProjectStore.writeContext(context, project: folder) }.value
        } catch {
            return fail(error.localizedDescription)
        }
        contexts[project.id] = context
        if let i = projects.firstIndex(where: { $0.id == project.id }) { projects[i].hasContext = true }
        projectSetup?.context = context
        projectSetup?.isRunning = false
    }

    /// A3 "Add Rule".
    func addRule(_ rule: String, to project: Project) throws {
        try ProjectStore.addRule(rule, project: project.folder)
        let context = ProjectStore.readContext(project: project.folder)
        contexts[project.id] = context
        if projectSetup?.project.id == project.id, let context {
            projectSetup?.context?.principles = context.principles
        }
    }

    /// A3 "Edit Files": opens `.mel/project/` in Finder.
    func showContext(of project: Project) {
        SystemActions.showInFinder(ProjectStore.contextFolder(project: project.folder))
    }

    // MARK: - Specs

    /// B1. Creates `specs/<slug>/` in `project` and copies attachments, then selects the spec; the
    /// caller then calls `start()` on the session. Without a project (A4x, Product only) a new
    /// project folder is made under `parent`, by default `~/Developer` (created if missing).
    /// Name it `Spec.untitledName` to let intake name it.
    func createSpec(name: String, idea: String, size: SpecSize, project: Project?, parent: URL? = nil, buildsOn: [String] = [], fillGaps: Bool = true, files: [URL] = [], logs: [String] = []) throws -> SpecSession {
        let isNew = project == nil
        let project = try project ?? createProject(name: name, parent: parent ?? developerFolder)
        if isNew { ideaProjects.insert(project.id) }
        let folder = SpecStore.freeFolder(name: name, in: project.folder.appending(path: "specs", directoryHint: .isDirectory))
        let spec = Spec(name: name, idea: idea, size: size, folder: folder, buildsOn: buildsOn, fillGaps: fillGaps, language: specLanguage)
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
        selection = specs(in: project).first?.id ?? selection
    }

    func removeMissing(_ missing: URL) {
        missingFolders.removeAll { $0 == missing }
        saveLibrary()
    }

    /// B1 "Save to": `<project>/specs/<slug>/`, or with no project (Product) `<parent>/<slug>/specs/<slug>/`.
    func specFolder(name: String, size: SpecSize, project: Project?, parent: URL) -> URL {
        let slug = SpecStore.slug(name)
        return SpecStore.specFolder(slug: slug, project: project?.folder ?? parent.appending(path: slug, directoryHint: .isDirectory))
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

    /// One agent run at a time across the app: a spec's, or A3's.
    var isAgentBusy: Bool { runningSpecID != nil || projectSetup?.isRunning == true }

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

    /// Adds the project with its context and specs. A file that was being written when Mel quit
    /// becomes stopped, and an analyze run that was going shows Rerun.
    @discardableResult
    private func load(_ folder: URL) -> Project {
        let context = ProjectStore.readContext(project: folder)
        let project = Project(folder: folder, hasContext: context != nil)
        projects.append(project)
        contexts[project.id] = context
        branches[project.id] = Git.branch(at: folder)
        for var spec in SpecStore.scan(project: project.folder) where !specs.contains(where: { $0.id == spec.id }) {
            if case .drafting = spec.stage { spec.apply(.draftStopped(.crashed("Mel quit while this file was being written."))) }
            // A board that was working when Mel quit waits for Resume: nothing runs on launch.
            if spec.halted == nil, let step = spec.nextStep { spec.halt(.user, during: step) }
            if spec.stage == .analyze, spec.analyze == .running { spec.apply(.analyzeFailed) }
            specs.append(spec)
        }
        return project
    }

    private func saveLibrary() {
        guard !isPreview else { return }
        library.save(projects.map(\.folder) + missingFolders)
    }

    static func preview(_ specs: [Spec], agent: AgentStatus, projects: [Project] = [], contexts: [Project.ID: ProjectContext] = [:], foundRepositories: [FoundRepository] = [], projectSetup: ProjectSetup? = nil, branches: [Project.ID: String] = [:], sessions: [SpecSession] = []) -> AppState {
        let state = AppState(adapter: InertAdapter(), makeRunner: { _ in InertRunner() }, defaults: UserDefaults(suiteName: "preview")!)
        state.isPreview = true
        state.specs = specs
        state.agent = agent
        state.projects = projects
        state.contexts = contexts
        state.foundRepositories = foundRepositories
        state.projectSetup = projectSetup
        state.branches = branches
        for session in sessions { state.sessions[session.spec.id] = session }   // fixtures with live text, activity, step
        state.selection = specs.first?.id
        return state
    }
}

/// A3's run. `isNewProject`: the folder was empty ("New project, no code yet").
struct ProjectSetup: Hashable {
    var project: Project
    var isNewProject: Bool
    var isRunning: Bool
    var activity: [ActivityLine]
    var context: ProjectContext?
    var lastError: String?
    /// A3 header: the current git branch and the number of files Mel can read.
    var branch: String? = nil
    var fileCount: Int? = nil
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
