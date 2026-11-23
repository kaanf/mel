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
    var specs: [Spec] = []
    var missingFolders: [URL] = []
    var selection: Spec.ID?
    var runningSpecID: Spec.ID?

    @ObservationIgnored private let adapter: any AgentAdapter
    @ObservationIgnored private let makeRunner: @Sendable (URL) -> any AgentRunning
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let library: Library
    @ObservationIgnored private var sessions: [Spec.ID: SpecSession] = [:]
    @ObservationIgnored private var isPreview = false
    private static let searchPathsKey = "extraSearchPaths"

    /// Composition root passes `ClaudeCode()` and `{ AgentRunner(adapter: ClaudeCode(), executable: $0) }`;
    /// tests and previews pass fakes. Restores the library.
    init(adapter: any AgentAdapter, makeRunner: @escaping @Sendable (URL) -> any AgentRunning, defaults: UserDefaults = .standard) {
        self.adapter = adapter
        self.makeRunner = makeRunner
        self.defaults = defaults
        library = Library(defaults: defaults)
        extraSearchPaths = defaults.stringArray(forKey: Self.searchPathsKey) ?? []
        for item in library.load() {
            if !item.isMissing, let spec = Self.loadSpec(in: item.folder) {
                specs.append(spec)
            } else {
                missingFolders.append(item.folder)
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

    /// Creates the folder and the spec; the caller then calls `start()` on the session.
    func createSpec(name: String, idea: String, parentFolder: URL) throws -> SpecSession {
        let spec = Spec(name: name, idea: idea, folder: specFolder(name: name, parent: parentFolder))
        try SpecStore.create(spec)
        specs.append(spec)
        saveLibrary()
        selection = spec.id
        return session(for: spec.id)
    }

    func removeFromLibrary(_ id: Spec.ID) {
        specs.removeAll { $0.id == id }
        sessions[id] = nil
        if selection == id { selection = nil }
        saveLibrary()
    }

    /// "Locate…": `folder` is the moved project folder or its `specs` folder.
    func locate(_ missing: URL, at folder: URL) throws {
        let specsFolder = FileManager.default.fileExists(atPath: folder.appending(path: ".mel").path) ? folder : folder.appending(path: "specs")
        var spec = try SpecStore.loadState(in: specsFolder)
        spec.folder = specsFolder
        missingFolders.removeAll { $0 == missing }
        specs.removeAll { $0.id == spec.id }
        specs.append(spec)
        saveLibrary()
        selection = spec.id
    }

    func removeMissing(_ missing: URL) {
        missingFolders.removeAll { $0 == missing }
        saveLibrary()
    }

    func specFolder(name: String, parent: URL) -> URL { SpecStore.specsFolder(name: name, parent: parent) }

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

    /// A runner for the detected executable, or nil while Claude Code isn't ready.
    func makeAgentRunner() -> (any AgentRunning)? {
        guard case .ready(let executable, _) = agent else { return nil }
        return makeRunner(executable)
    }

    /// Keeps the sidebar in step with a session's spec.
    func update(_ spec: Spec) {
        guard let i = specs.firstIndex(where: { $0.id == spec.id }) else { return }
        specs[i] = spec
    }

    // MARK: - Library

    private func saveLibrary() {
        guard !isPreview else { return }
        library.save(specs.map(\.folder) + missingFolders)
    }

    /// The saved spec, with `folder` where it is now. A file that was being written when
    /// Mel quit becomes stopped, so the user can resume it.
    private static func loadSpec(in folder: URL) -> Spec? {
        guard var spec = try? SpecStore.loadState(in: folder) else { return nil }
        spec.folder = folder
        if case .drafting = spec.stage { spec.apply(.draftStopped(.crashed("Mel quit while this file was being written."))) }
        return spec
    }

    static func preview(_ specs: [Spec], agent: AgentStatus) -> AppState {
        let state = AppState(adapter: InertAdapter(), makeRunner: { _ in InertRunner() }, defaults: UserDefaults(suiteName: "preview")!)
        state.isPreview = true
        state.specs = specs
        state.agent = agent
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
