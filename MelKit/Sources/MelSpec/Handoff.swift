import Foundation

/// One `- [ ] N. Title` task in TASKS.md (V2.md §6), as B7 lists it.
public struct SpecTask: Identifiable, Hashable, Sendable {
    public var number: Int
    public var title: String
    public var priority: String
    public var covers: [String]
    public var reads: String
    public var verify: String
    public var parallelWith: [Int]
    /// The folders it changes (`Changes:`); two tasks in one step that share one run one after the other.
    public var changes: [String]
    /// The `## 1 · Foundation` heading it sits under ("Foundation"), or "" for a TASKS.md without phases.
    public var phase: String
    public var id: Int { number }

    public init(number: Int, title: String, priority: String, covers: [String], reads: String, verify: String, parallelWith: [Int] = [], changes: [String] = [], phase: String = "") {
        self.number = number
        self.title = title
        self.priority = priority
        self.covers = covers
        self.reads = reads
        self.verify = verify
        self.parallelWith = parallelWith
        self.changes = changes
        self.phase = phase
    }

    /// `- [ ] N. Title` lines, their indented `- Key: value` fields and the `## N · Phase` heading above them.
    public static func parse(_ tasks: String) -> [SpecTask] {
        var result: [SpecTask] = []
        var phase = ""
        for line in tasks.split(whereSeparator: \.isNewline) {
            let trimmed = line.trimming(while: \.isWhitespace)
            if line.hasPrefix("## ") {
                // "## 2 · Booking and paying" → "Booking and paying"
                let heading = line.dropFirst(3).trimming(while: \.isWhitespace)
                let number = heading.prefix(while: \.isNumber)
                let rest = heading.dropFirst(number.count).trimming(while: { $0 == "·" || $0 == "." || $0.isWhitespace })
                phase = String(number.isEmpty || rest.isEmpty ? heading : rest)
            } else if line.first?.isWhitespace != true, trimmed.hasPrefix("- ["), trimmed.dropFirst(3).first != nil, trimmed.dropFirst(4).hasPrefix("] ") {
                let rest = trimmed.dropFirst(6)
                let digits = rest.prefix(while: \.isNumber)
                guard let number = Int(digits) else { continue }
                let title = rest.dropFirst(digits.count).trimming(while: { $0 == "." || $0.isWhitespace })
                result.append(SpecTask(number: number, title: String(title), priority: "", covers: [], reads: "", verify: "", phase: phase))
            } else if !result.isEmpty, trimmed.hasPrefix("- "), let colon = trimmed.firstIndex(of: ":") {
                let key = trimmed[trimmed.index(trimmed.startIndex, offsetBy: 2)..<colon]
                let value = String(trimmed[trimmed.index(after: colon)...].trimming(while: \.isWhitespace))
                let list = value.split(separator: ",").map { String($0.trimming(while: \.isWhitespace)) }
                switch key {
                case "Priority": result[result.count - 1].priority = value
                case "Covers": result[result.count - 1].covers = list
                case "Reads": result[result.count - 1].reads = value
                case "Verify": result[result.count - 1].verify = value.trimmingCharacters(in: ["`"])
                case "Parallel with": result[result.count - 1].parallelWith = list.compactMap { Int($0) }
                case "Changes": result[result.count - 1].changes = list.map { $0.trimmingCharacters(in: ["`"]) }
                default: break
                }
            }
        }
        return result
    }

    /// `prompts/task-NN.md`.
    public var promptFileName: String { String(format: "task-%02d.md", number) }

    /// The prompt file: the task, the criteria it covers in full, what it reads, the verify command.
    public func prompt(requirements: String) -> String {
        var criteria: [String: String] = [:]
        for case .criterion(let id, let text) in MarkdownParser.blocks(requirements) { criteria[id] = text }
        var lines = ["# Task \(number) · \(title)", ""]
        let meta = [priority.isEmpty ? nil : "Priority: \(priority)",
                    parallelWith.isEmpty ? nil : "Parallel with: \(parallelWith.map(String.init).joined(separator: ", "))"].compactMap { $0 }
        if !meta.isEmpty { lines += [meta.joined(separator: " · "), ""] }
        lines += ["Implement task \(number) of TASKS.md in the folder above this one. The spec files there are the source of truth.", ""]
        if !covers.isEmpty {
            lines += ["## Acceptance criteria", ""]
            lines += covers.map { "- \($0) \(criteria[$0] ?? "(see REQUIREMENTS.md)")" }
            lines.append("")
        }
        if !reads.isEmpty { lines += ["## Read first", "", reads, ""] }
        if !verify.isEmpty { lines += ["## Done when", "", "`\(verify)` passes and every criterion above holds.", ""] }
        return lines.joined(separator: "\n")
    }
}
