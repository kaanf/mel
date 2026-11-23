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
        spec.coverage = [CoverageItem(label: "Payments", phase: .requirements, state: .covered), CoverageItem(label: "Cancellations", phase: .requirements, state: .notYet)]
        #expect(spec.answersText == """
            - How do members pay? At the desk (cash only)
            - Is there a waitlist? You decide: choose the best option and mark it as an assumption.
            """)
        #expect(spec.coverageText == "- Payments (requirements): covered\n- Cancellations (requirements): notYet")
        #expect(spec.decideText == "- Is there a waitlist?\n- Cancellations")
    }

    @Test func coverageCarriesItsPhaseAndMissingPhaseIsProduct() throws {
        let turn = try DiscoveryTurn.decode(#"{"coverage":[{"label":"Problem","state":"covered"},{"label":"Screens","phase":"architecture","state":"notYet"}],"done":true}"#)
        #expect(turn.coverage == [CoverageItem(label: "Problem", phase: .product, state: .covered), CoverageItem(label: "Screens", phase: .architecture, state: .notYet)])
    }

    @Test func emptyOrMissingOptionsIsAnOpenQuestion() throws {
        let empty = try DiscoveryTurn.decode(#"{"coverage":[],"next":{"id":"design-ideas","title":"What do you have in mind for the design?","shapes":"architecture","options":[]},"done":false}"#)
        #expect(empty.next?.options == [])
        #expect(empty.next?.shapes == .architecture)
        #expect(!empty.done)
        let missing = try DiscoveryTurn.decode(#"{"coverage":[],"next":{"id":"idea","title":"Tell me more.","shapes":"product"}}"#)
        #expect(missing.next?.options == [])
    }

    @Test func freeTextAnswersKeepTheirLinesInTheList() {
        var spec = Spec(name: "Yoga", idea: "Book classes", folder: URL(filePath: "/tmp/yoga/specs"))
        spec.questions = [Question(id: "design-ideas", title: "What do you have in mind for the design?", why: "", shapes: .architecture, options: [], answer: .text("Calm, like Things.\nTwo tabs."))]
        #expect(spec.answersText == "- What do you have in mind for the design? Calm, like Things.\n  Two tabs.")
        #expect(spec.decideText == "(nothing)")
    }
}
