import Foundation

/// Send tasks (V2-35, OQ #47): one issue per task, for GitHub Issues or Linear. Built in Swift, no tokens.
public struct IssueDraft: Hashable, Sendable {
    public var task: Int
    public var title: String
    public var body: String
    /// The task's phase, as a GitHub milestone; nil when off or the plan has no phases.
    public var milestone: String?

    /// `checklist`: the criteria the task covers as `- [ ]` lines, from REQUIREMENTS.md (or SPEC.md).
    public static func drafts(tasks: [SpecTask], criteria: [(id: String, text: String)], slug: String, checklist: Bool, milestones: Bool) -> [IssueDraft] {
        let byID = Dictionary(criteria.map { ($0.id, ProjectSpec.tag(of: $0.text)?.text ?? $0.text) }) { first, _ in first }
        return tasks.map { task in
            var body = "Task \(task.number) of the spec `specs/\(slug)` (planned with Mel)."
            if checklist {
                let lines = task.covers.compactMap { id in byID[id].map { "- [ ] \(id) \($0)" } }
                if !lines.isEmpty { body += "\n\n## Done when\n\n" + lines.joined(separator: "\n") }
            }
            if !task.verify.isEmpty { body += "\n\n## Check\n\n`\(task.verify)`" }
            if !task.changes.isEmpty { body += "\n\n## Changes\n\n" + task.changes.map { "- `\($0)`" }.joined(separator: "\n") }
            return IssueDraft(task: task.number, title: task.title, body: body, milestone: milestones && !task.phase.isEmpty ? task.phase : nil)
        }
    }

    /// The label every issue of a spec gets: `mel · <slug>`.
    public static func label(slug: String) -> String { "mel · \(slug)" }
}

/// A Linear team to send to.
public struct LinearTeam: Hashable, Sendable, Decodable {
    public var id: String
    public var name: String
    public var key: String

    public init(id: String, name: String, key: String) { (self.id, self.name, self.key) = (id, name, key) }
}
