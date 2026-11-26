import Foundation

/// One Discovery reply from the agent (AGENT-INTEGRATION.md › Structured (JSON) stages).
/// Coverage items carry their phase; a question with no options is an open question.
public struct DiscoveryTurn: Hashable, Sendable {
    public var coverage: [CoverageItem]
    public var next: Question?
    public var done: Bool

    public init(coverage: [CoverageItem], next: Question?, done: Bool) {
        self.coverage = coverage
        self.next = next
        self.done = done
    }

    /// Decodes the JSON object in `reply`. Text around the object (a stray code fence) is ignored.
    public static func decode(_ reply: String) throws -> DiscoveryTurn {
        let wire = try JSONDecoder().decode(Wire.self, from: jsonObject(in: reply))
        let next = wire.next?.question(round: .intake, shapes: .product)
        return DiscoveryTurn(coverage: wire.coverage, next: next, done: wire.done ?? (next == nil))
    }

    private struct Wire: Decodable {
        var coverage: [CoverageItem]
        var next: WireQuestion?
        var done: Bool?
    }
}

/// The one-shot intake reply (V2.md §5 Intake): every round-1 question and the coverage list.
public struct Intake: Hashable, Sendable {
    /// A short Title Case name for the spec, used when the user typed none.
    public var name: String?
    public var coverage: [CoverageItem]
    public var questions: [Question]

    public init(name: String? = nil, coverage: [CoverageItem], questions: [Question]) {
        self.name = name
        self.coverage = coverage
        self.questions = questions
    }

    public static func decode(_ reply: String, size: SpecSize) throws -> Intake {
        let wire = try JSONDecoder().decode(Wire.self, from: jsonObject(in: reply))
        let name = wire.name?.trimmingCharacters(in: .whitespacesAndNewlines)
        return Intake(name: name?.isEmpty == false ? name : nil, coverage: wire.coverage, questions: wire.questions.map { $0.question(round: .intake, shapes: size.files[0]) })
    }

    private struct Wire: Decodable {
        var name: String?
        var coverage: [CoverageItem]
        var questions: [WireQuestion]
    }
}

/// A question as agents write it; optional fields get defaults.
struct WireQuestion: Decodable {
    var id: String
    var title: String
    var why: String?
    var shapes: DocKind?
    var about: String?
    var options: [WireOption]?

    struct WireOption: Decodable {
        var label: String
        var note: String?
        var suggested: Bool?
    }

    func question(round: QuestionRound, shapes fallback: DocKind) -> Question {
        Question(id: id, title: title, why: why ?? "", shapes: shapes ?? fallback, round: round,
                 options: (options ?? []).map { Option(label: $0.label, note: $0.note ?? "", suggested: $0.suggested ?? false) },
                 about: about?.isEmpty == false ? about : nil)
    }
}

/// The outermost JSON object or array in an agent reply; text around it (a stray code fence) is ignored.
func jsonObject(in reply: String, open: Character = "{", close: Character = "}") throws -> Data {
    guard let start = reply.firstIndex(of: open), let end = reply.lastIndex(of: close), start < end else {
        throw DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: "No JSON in the reply."))
    }
    return Data(reply[start...end].utf8)
}

// Prompt text for `{{answers}}`, `{{coverage}}` and `{{decide}}`.
extension Spec {
    /// One line per answered question; "You decide" answers say so.
    public var answersText: String {
        let lines = questions.compactMap { q -> String? in
            guard let answer = q.answerText else { return nil }
            return "- \(q.title) \(answer.split(separator: "\n", omittingEmptySubsequences: false).joined(separator: "\n  "))"
        }
        return lines.isEmpty ? "(none yet)" : lines.joined(separator: "\n")
    }

    /// Empty on the first turn, which tells the agent to propose the list.
    public var coverageText: String {
        coverage.map { "- \($0.label) (\($0.phase.rawValue)): \($0.state.rawValue)" }.joined(separator: "\n")
    }

    /// "You decide" answers and topics Discovery didn't cover (Draft Now).
    public var decideText: String {
        let decided = questions.filter { $0.answer == .agentDecides }.map(\.title)
        let open = coverage.filter { $0.state != .covered }.map(\.label)
        let lines = (decided + open).map { "- \($0)" }
        return lines.isEmpty ? "(nothing)" : lines.joined(separator: "\n")
    }
}

extension Question {
    /// The answer as prompt text, or nil while unanswered.
    public var answerText: String? {
        switch answer {
        case nil: nil
        case .agentDecides: "You decide: choose the best option and mark it as an assumption."
        case .option(let i, let note): (options.indices.contains(i) ? options[i].label : "?") + (note.map { " (\($0))" } ?? "")
        case .text(let text): text
        }
    }
}
