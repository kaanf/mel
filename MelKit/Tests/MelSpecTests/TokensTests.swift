import Foundation
import Testing
@testable import MelSpec

struct TokensTests {
    @Test(arguments: [(0, "0"), (850, "850"), (1_000, "1.0k"), (1_820, "1.8k"), (9_949, "9.9k"), (9_950, "10k"), (41_300, "41k"), (141_600, "142k")])
    func text(_ tokens: Int, _ expected: String) {
        #expect(TokenStep.text(tokens) == expected)
    }

    @Test func tokensSumPerStepInPopoverOrder() {
        var spec = Spec(name: "Yoga", idea: "x", size: .feature, folder: URL(filePath: "/tmp/yoga/specs/yoga"))
        #expect(spec.tokenTotal == 0)
        #expect(spec.tokenSteps.isEmpty)
        spec.addTokens(1_800, to: .changes)
        spec.addTokens(4_000, to: TokenStep(file: .requirements))
        spec.addTokens(200, to: .changes)
        spec.addTokens(900, to: .questions)
        #expect(spec.tokenTotal == 6_900)
        #expect(spec.tokenSteps.map(\.step) == [.questions, .requirements, .changes])
        #expect(spec.tokenSteps.map(\.tokens) == [900, 4_000, 2_000])
        #expect(spec.tokenSteps.map(\.step.title) == ["Questions", "REQUIREMENTS.md", "Changes"])
    }

    @Test func stateWithoutTokensDecodes() throws {
        let spec = Spec(name: "Yoga", idea: "x", folder: URL(filePath: "/tmp/yoga/specs/yoga"))
        var object = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(spec)) as? [String: Any])
        #expect(object["tokens"] == nil)
        object["tokens"] = ["changes": 1_800, "requirements": 4_000]
        let decoded = try JSONDecoder().decode(Spec.self, from: JSONSerialization.data(withJSONObject: object))
        #expect(decoded.tokens == [.changes: 1_800, .requirements: 4_000])
    }
}
