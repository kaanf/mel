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
    public var id: Int { number }

    public init(number: Int, title: String, priority: String, covers: [String], reads: String, verify: String, parallelWith: [Int] = []) {
        self.number = number
        self.title = title
        self.priority = priority
        self.covers = covers
        self.reads = reads
        self.verify = verify
        self.parallelWith = parallelWith
    }

    public static func parse(_ tasks: String) -> [SpecTask] { [] }

    /// `prompts/task-NN.md`.
    public var promptFileName: String { String(format: "task-%02d.md", number) }

    /// The prompt file: the task, the criteria it covers in full, what it reads, the verify command.
    public func prompt(requirements: String) -> String { fatalError("stub") }
}
