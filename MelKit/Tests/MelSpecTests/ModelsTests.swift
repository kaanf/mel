import Foundation
import Testing
@testable import MelSpec

struct ModelsTests {
    @Test func docKindFileName() {
        #expect(DocKind.allCases.map(\.fileName) == ["PRODUCT.md", "REQUIREMENTS.md", "DESIGN.md", "TASKS.md"])
        #expect(DocKind.requirements.title == "Requirements")
    }

    @Test func stateFromBeforePhasesLoadsCoverageAsProduct() throws {
        let old = #"{"label":"Payments","state":"covered"}"#
        #expect(try JSONDecoder().decode(CoverageItem.self, from: Data(old.utf8)) == CoverageItem(label: "Payments", phase: .product, state: .covered))
        let item = CoverageItem(label: "Screens", phase: .design, state: .asking)
        #expect(try JSONDecoder().decode(CoverageItem.self, from: JSONEncoder().encode(item)) == item)
    }

    @Test func textAnswerRoundTrips() throws {
        let answer = Answer.text("Calm, like Things.")
        #expect(try JSONDecoder().decode(Answer.self, from: JSONEncoder().encode(answer)) == answer)
    }
}
