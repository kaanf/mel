import Foundation
import Observation

@Observable final class AppState {
    var agent: AgentStatus = .checking
    var extraSearchPaths: [String] = []
    var specs: [Spec] = []
    var selection: Spec.ID?
    var runningSpecID: Spec.ID?

    func scanForAgent() async { fatalError("stub") }

    func session(for id: Spec.ID) -> SpecSession {
        guard let spec = specs.first(where: { $0.id == id }) else { fatalError("unknown spec \(id)") }
        return .preview(spec)
    }

    func createSpec(name: String, idea: String, parentFolder: URL) throws -> SpecSession { fatalError("stub") }
    func removeFromLibrary(_ id: Spec.ID) { fatalError("stub") }

    static func preview(_ specs: [Spec], agent: AgentStatus) -> AppState {
        let state = AppState()
        state.specs = specs
        state.agent = agent
        state.selection = specs.first?.id
        return state
    }
}
