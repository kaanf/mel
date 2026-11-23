import Foundation
import Observation

@Observable final class SpecSession {
    private(set) var spec: Spec
    private(set) var documents: [DocKind: String]
    private(set) var liveText: String
    private(set) var activity: [ActivityLine]
    private(set) var isRunning: Bool
    private(set) var lastError: String?

    private init(spec: Spec, documents: [DocKind: String], liveText: String, activity: [ActivityLine], isRunning: Bool) {
        self.spec = spec
        self.documents = documents
        self.liveText = liveText
        self.activity = activity
        self.isRunning = isRunning
    }

    var currentQuestion: Question? { spec.questions.first { $0.answer == nil } }
    var answeredQuestions: [Question] { spec.questions.filter { $0.answer != nil } }

    func summary(_ kind: DocKind) -> DocSummary {
        MarkdownParser.summary(documents[kind] ?? "", kind: kind)
    }

    // Discovery
    func start() async { fatalError("stub") }
    func answer(_ answer: Answer) async { fatalError("stub") }
    func changeAnswer(questionID: String, to answer: Answer) async { fatalError("stub") }
    func draftNow() async { fatalError("stub") }
    func retry() async { fatalError("stub") }

    // Drafting / recovery
    func stop() async { fatalError("stub") }
    func resume() async { fatalError("stub") }
    func finishByHand() { fatalError("stub") }

    // Review
    func save(_ text: String, for kind: DocKind) { fatalError("stub") }
    func confirmAssumption(index: Int, in kind: DocKind) { fatalError("stub") }
    func changeAssumption(index: Int, to text: String, in kind: DocKind) { fatalError("stub") }
    func approve(_ kind: DocKind) async { fatalError("stub") }

    static func preview(_ spec: Spec, documents: [DocKind: String] = [:], liveText: String = "", activity: [ActivityLine] = [], isRunning: Bool = false) -> SpecSession {
        SpecSession(spec: spec, documents: documents, liveText: liveText, activity: activity, isRunning: isRunning)
    }
}
