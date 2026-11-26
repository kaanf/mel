import Foundation

/// Prompt templates bundled from `Prompts/*.md`, filled by plain `{{placeholder}}` replacement.
/// Drafting, revise and rewrite prompts share the rules through `{{rules}}`, which `build` fills itself:
/// `rules.md`, or `rules-no-gaps.md` when the user turned "Let Mel fill small gaps" off.
/// With a `language`, `language.md` is appended so every prompt of a spec writes in it.
public enum Prompt: String, CaseIterable, Sendable {
    case project, intake
    case discovery                  // v1, until SpecSession runs the intake (Wave 7)
    case product, requirements, experience, architecture, tasks, spec
    /// `revise` replies with a `Patch`; `rewrite` streams the whole file, only after an unplaced patch (OQ #25).
    case revise, rewrite, analyze, impact
    case `continue`

    public init(drafting kind: DocKind) {
        self = Prompt(rawValue: kind.rawValue)!
    }

    /// The template with each `{{key}}` replaced by `values[key]` in one pass, so values that
    /// contain `{{…}}` themselves are left alone. Unknown keys stay as written.
    public func build(_ values: [String: String], fillGaps: Bool = true, language: SpecLanguage? = nil) -> String {
        let values = values.merging(["rules": Self.load(fillGaps ? "rules" : "rules-no-gaps")]) { mine, _ in mine }
        var output = ""
        var rest = Self.load(rawValue)[...]
        while let open = rest.range(of: "{{"), let close = rest[open.upperBound...].range(of: "}}") {
            output += rest[..<open.lowerBound]
            output += values[String(rest[open.upperBound..<close.lowerBound])] ?? String(rest[open.lowerBound..<close.upperBound])
            rest = rest[close.upperBound...]
        }
        output += rest
        guard let language else { return output }
        return output + "\n\n" + Self.load("language").replacing("{{language}}", with: language.promptName)
    }

    static func load(_ name: String) -> String {
        let url = Bundle.module.url(forResource: name, withExtension: "md")!
        return try! String(contentsOf: url, encoding: .utf8)
    }
}

// Prompt text for `{{steps}}`, `{{files}}` and `{{kinds}}`.
extension DocKind {
    /// B3's steps as a numbered list; the agent marks each with `<!-- mel:step N -->`.
    public var stepsText: String {
        draftSteps.enumerated().map { "\($0.offset + 1). \($0.element)" }.joined(separator: "\n")
    }
}

extension SpecSize {
    /// "REQUIREMENTS.md, ARCHITECTURE.md, TASKS.md".
    public var filesText: String { files.map(\.fileName).joined(separator: ", ") }

    /// "`requirements`, `architecture`, `tasks`": the JSON values a reply may use for a file.
    public var kindsText: String { files.map { "`\($0.rawValue)`" }.joined(separator: ", ") }
}
