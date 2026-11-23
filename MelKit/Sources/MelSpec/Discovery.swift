import Foundation

/// One Discovery reply from the agent (AGENT-INTEGRATION.md › Structured (JSON) stages).
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
        guard let start = reply.firstIndex(of: "{"), let end = reply.lastIndex(of: "}"), start < end else {
            throw DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: "No JSON object in the reply."))
        }
        let wire = try JSONDecoder().decode(Wire.self, from: Data(reply[start...end].utf8))
        let next = wire.next.map { q in
            Question(id: q.id, title: q.title, why: q.why ?? "", shapes: q.shapes,
                     options: q.options.map { Option(label: $0.label, note: $0.note ?? "", suggested: $0.suggested ?? false) })
        }
        return DiscoveryTurn(coverage: wire.coverage, next: next, done: wire.done ?? (next == nil))
    }

    private struct Wire: Decodable {
        var coverage: [CoverageItem]
        var next: WireQuestion?
        var done: Bool?
    }

    private struct WireQuestion: Decodable {
        var id: String
        var title: String
        var why: String?
        var shapes: DocKind
        var options: [WireOption]
    }

    private struct WireOption: Decodable {
        var label: String
        var note: String?
        var suggested: Bool?
    }
}

// Prompt text for `{{answers}}`, `{{coverage}}` and `{{decide}}`.
extension Spec {
    /// One line per answered question; "You decide" answers say so.
    public var answersText: String {
        let lines = questions.compactMap { q -> String? in
            switch q.answer {
            case nil:
                return nil
            case .agentDecides:
                return "- \(q.title) You decide: choose the best option and mark it as an assumption."
            case .option(let i, let note):
                let option = q.options.indices.contains(i) ? q.options[i].label : "?"
                let extra = note.map { " (\($0))" } ?? ""
                return "- \(q.title) \(option)\(extra)"
            }
        }
        return lines.isEmpty ? "(none yet)" : lines.joined(separator: "\n")
    }

    /// Empty on the first turn, which tells the agent to propose the list.
    public var coverageText: String {
        coverage.map { "- \($0.label): \($0.state.rawValue)" }.joined(separator: "\n")
    }

    /// "You decide" answers and topics Discovery didn't cover (Draft Now).
    public var decideText: String {
        let decided = questions.filter { $0.answer == .agentDecides }.map(\.title)
        let open = coverage.filter { $0.state != .covered }.map(\.label)
        let lines = (decided + open).map { "- \($0)" }
        return lines.isEmpty ? "(nothing)" : lines.joined(separator: "\n")
    }
}
