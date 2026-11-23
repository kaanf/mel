import Foundation
import Testing
import MelSpec
@testable import Mel

struct AppStateTests {
    @Test func previewSelectsFirstSpec() {
        let spec = Spec(name: "Yoga", idea: "Book classes", folder: URL(filePath: "/tmp/yoga/specs"), stage: .discovery, docs: [:], questions: [], coverage: [])
        let state = AppState.preview([spec], agent: .missing)
        #expect(state.selection == spec.id)
        #expect(state.session(for: spec.id).spec == spec)
    }
}
