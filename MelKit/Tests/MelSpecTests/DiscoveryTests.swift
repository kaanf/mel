import Foundation
import Testing
@testable import MelSpec

struct DiscoveryTests {
    @Test func decodesTheDocumentedReply() throws {
        let reply = #"{"coverage":[{"label":"Problem","state":"covered"},{"label":"Payments","state":"asking"},{"label":"Cancellations","state":"notYet"}],"next":{"id":"payments","title":"How do members pay?","why":"Decides checkout.","shapes":"requirements","options":[{"label":"Class packs","note":"From your idea","suggested":true},{"label":"At the desk","note":"No checkout"}]},"done":false}"#
        let turn = try DiscoveryTurn.decode(reply)
        #expect(turn.coverage.map(\.state) == [.covered, .asking, .notYet])
        #expect(turn.next?.id == "payments")
        #expect(turn.next?.shapes == .requirements)
        #expect(turn.next?.options == [Option(label: "Class packs", note: "From your idea", suggested: true), Option(label: "At the desk", note: "No checkout")])
        #expect(turn.next?.answer == nil)
        #expect(!turn.done)
    }

    @Test func toleratesACodeFence() throws {
        let turn = try DiscoveryTurn.decode("```json\n{\"coverage\":[{\"label\":\"Problem\",\"state\":\"covered\"}],\"done\":true}\n```")
        #expect(turn.done)
        #expect(turn.next == nil)
    }

    @Test func missingDoneMeansDoneWhenThereIsNoNextQuestion() throws {
        #expect(try DiscoveryTurn.decode(#"{"coverage":[]}"#).done)
    }

    @Test func proseIsAnError() {
        #expect(throws: (any Error).self) { try DiscoveryTurn.decode("Sure! Here are some questions.") }
        #expect(throws: (any Error).self) { try DiscoveryTurn.decode(#"{"coverage":"nope"}"#) }
    }

    @Test func promptTextFromAnswersAndCoverage() {
        let options = [Option(label: "Class packs", note: ""), Option(label: "At the desk", note: "")]
        var spec = Spec(name: "Yoga", idea: "Book classes", folder: URL(filePath: "/tmp/yoga/specs"))
        #expect(spec.answersText == "(none yet)")
        #expect(spec.coverageText == "")
        #expect(spec.decideText == "(nothing)")

        spec.questions = [
            Question(id: "pay", title: "How do members pay?", why: "", shapes: .requirements, options: options, answer: .option(1, note: "cash only")),
            Question(id: "wait", title: "Is there a waitlist?", why: "", shapes: .requirements, options: options, answer: .agentDecides),
            Question(id: "open", title: "Open question?", why: "", shapes: .product, options: options),
        ]
        spec.coverage = [CoverageItem(label: "Payments", state: .covered), CoverageItem(label: "Cancellations", state: .notYet)]
        #expect(spec.answersText == """
            - How do members pay? At the desk (cash only)
            - Is there a waitlist? You decide: choose the best option and mark it as an assumption.
            """)
        #expect(spec.coverageText == "- Payments: covered\n- Cancellations: notYet")
        #expect(spec.decideText == "- Is there a waitlist?\n- Cancellations")
    }
}
