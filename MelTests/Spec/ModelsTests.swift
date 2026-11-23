import Testing
@testable import Mel

struct ModelsTests {
    @Test func docKindFileName() {
        #expect(DocKind.allCases.map(\.fileName) == ["PRODUCT.md", "REQUIREMENTS.md", "DESIGN.md", "TASKS.md"])
        #expect(DocKind.requirements.title == "Requirements")
    }
}
