import Foundation

/// Where a spec's tokens went: the rows of the token popover, in order (FLOW.md › V2, V2-9).
public enum TokenStep: String, Codable, CodingKeyRepresentable, CaseIterable, Hashable, Sendable {
    case questions
    case product, requirements, experience, architecture, tasks, spec
    /// Analyze and impact runs.
    case checks
    /// Patch runs and whole-file rewrites.
    case changes

    public init(file kind: DocKind) {
        self = TokenStep(rawValue: kind.rawValue)!
    }

    public var title: String {
        switch self {
        case .questions: "Questions"
        case .checks: "Checks"
        case .changes: "Changes"
        default: DocKind(rawValue: rawValue)!.fileName
        }
    }

    /// "850", "1.8k", "41k".
    public static func text(_ tokens: Int) -> String {
        switch tokens {
        case ..<1000: "\(tokens)"
        case ..<9950: "\((Double(tokens) / 1000).formatted(.number.precision(.fractionLength(1)).locale(Locale(identifier: "en_US"))))k"
        default: "\(Int((Double(tokens) / 1000).rounded()))k"
        }
    }
}

extension Spec {
    public var tokenTotal: Int { tokens?.values.reduce(0, +) ?? 0 }

    /// The steps that used tokens, in popover order.
    public var tokenSteps: [(step: TokenStep, tokens: Int)] {
        TokenStep.allCases.compactMap { step in tokens?[step].map { (step, $0) } }
    }

    public mutating func addTokens(_ count: Int, to step: TokenStep) {
        tokens = (tokens ?? [:]).merging([step: count], uniquingKeysWith: +)
    }
}
