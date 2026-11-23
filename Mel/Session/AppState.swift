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
    private static let searchPathsKey = "extraSearchPaths"

    /// Composition root passes `ClaudeCode()` and `{ AgentRunner(adapter: ClaudeCode(), executable: $0) }`;
    /// tests and previews pass fakes.
    init(adapter: any AgentAdapter, makeRunner: @escaping @Sendable (URL) -> any AgentRunning, defaults: UserDefaults = .standard) {
        self.adapter = adapter
        self.makeRunner = makeRunner
        self.defaults = defaults
        extraSearchPaths = defaults.stringArray(forKey: Self.searchPathsKey) ?? []
    }

    func scanForAgent() async { fatalError("stub") }

    func session(for id: Spec.ID) -> SpecSession {
        guard let spec = specs.first(where: { $0.id == id }) else { fatalError("unknown spec \(id)") }
        return .preview(spec)
    }

    func createSpec(name: String, idea: String, parentFolder: URL) throws -> SpecSession { fatalError("stub") }
    func removeFromLibrary(_ id: Spec.ID) { fatalError("stub") }
    func locate(_ missing: URL, at folder: URL) throws { fatalError("stub") }
    func removeMissing(_ missing: URL) { fatalError("stub") }
    func specFolder(name: String, parent: URL) -> URL { SpecStore.specsFolder(name: name, parent: parent) }

    // System actions for views (views never import MelSystem)
    func signIn() { fatalError("stub") }
    func copy(_ text: String) { SystemActions.copy(text) }

    static func preview(_ specs: [Spec], agent: AgentStatus) -> AppState {
        let state = AppState(adapter: InertAdapter(), makeRunner: { _ in InertRunner() }, defaults: UserDefaults(suiteName: "preview")!)
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
