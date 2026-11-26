import Foundation
import Testing
@testable import MelSpec

struct DiscoveryTests {
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

    @Test func intakeDecodesInACodeFenceAndProseIsAnError() throws {
        let intake = try Intake.decode("```json\n{\"name\":\" Yoga \",\"coverage\":[{\"label\":\"Problem\",\"state\":\"covered\"},{\"label\":\"Screens\",\"phase\":\"architecture\",\"state\":\"notYet\"}],\"questions\":[{\"id\":\"idea\",\"title\":\"Tell me more.\"}]}\n```", size: .feature)
        #expect(intake.name == "Yoga")
        #expect(intake.coverage == [CoverageItem(label: "Problem", phase: .product, state: .covered), CoverageItem(label: "Screens", phase: .architecture, state: .notYet)])
        #expect(intake.questions.first?.options == [])   // no options: it takes a typed answer
        #expect(intake.questions.first?.shapes == .requirements)
        #expect(throws: (any Error).self) { try Intake.decode("Sure! Here are some questions.", size: .feature) }
    }

    @Test func freeTextAnswersKeepTheirLinesInTheList() {
        var spec = Spec(name: "Yoga", idea: "Book classes", folder: URL(filePath: "/tmp/yoga/specs"))
        spec.questions = [Question(id: "design-ideas", title: "What do you have in mind for the design?", why: "", shapes: .architecture, options: [], answer: .text("Calm, like Things.\nTwo tabs."))]
        #expect(spec.answersText == "- What do you have in mind for the design? Calm, like Things.\n  Two tabs.")
        #expect(spec.decideText == "(nothing)")
    }
}
