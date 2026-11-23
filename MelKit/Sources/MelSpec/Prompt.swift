import Foundation

/// Prompt templates bundled from `Prompts/*.md`, filled by plain `{{placeholder}}` replacement.
/// Drafting prompts share `rules.md` through `{{rules}}`, which `build` fills itself.
public enum Prompt: String, CaseIterable, Sendable {
    case discovery, product, requirements, design, tasks
    case `continue`

    // v1 templates until the v2 prompts land: EXPERIENCE and ARCHITECTURE use design.md, SPEC uses requirements.md.
    public init(drafting kind: DocKind) {
        switch kind {
        case .experience, .architecture: self = .design
        case .spec: self = .requirements
        default: self = Prompt(rawValue: kind.rawValue)!
        }
    }

    /// The template with each `{{key}}` replaced by `values[key]` in one pass, so values that
    /// contain `{{…}}` themselves are left alone. Unknown keys stay as written.
    public func build(_ values: [String: String]) -> String {
        let values = values.merging(["rules": Self.load("rules")]) { mine, _ in mine }
        var output = ""
        var rest = Self.load(rawValue)[...]
        while let open = rest.range(of: "{{"), let close = rest[open.upperBound...].range(of: "}}") {
            output += rest[..<open.lowerBound]
            output += values[String(rest[open.upperBound..<close.lowerBound])] ?? String(rest[open.lowerBound..<close.upperBound])
            rest = rest[close.upperBound...]
        }
        return output + rest
    }

    static func load(_ name: String) -> String {
        let url = Bundle.module.url(forResource: name, withExtension: "md")!
        return try! String(contentsOf: url, encoding: .utf8)
    }
}
