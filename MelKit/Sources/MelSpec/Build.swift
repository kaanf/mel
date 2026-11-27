import Foundation

/// V2-3 Build: TASKS.md in steps. A step opens when every task of the step before it is done.
public struct BuildStep: Hashable, Sendable {
    public enum Kind: Hashable, Sendable {
        /// One task.
        case alone
        /// Tasks marked `Parallel with` each other that change different folders: one terminal each.
        case together
        /// Tasks marked parallel that change a folder in common: one after the other, in order.
        case inOrder
    }

    public var kind: Kind
    public var tasks: [SpecTask]

    /// Tasks in build order; a run of tasks marked `Parallel with` each other is one step.
    public static func steps(_ tasks: [SpecTask]) -> [BuildStep] {
        var groups: [[SpecTask]] = []
        for task in tasks {
            if let last = groups.last, last.contains(where: { task.parallelWith.contains($0.number) || $0.parallelWith.contains(task.number) }) {
                groups[groups.count - 1].append(task)
            } else {
                groups.append([task])
            }
        }
        return groups.map { group in
            guard group.count > 1 else { return BuildStep(kind: .alone, tasks: group) }
            var seen = Set<String>()
            let shares = group.contains { task in !task.changes.allSatisfy { seen.insert($0).inserted } }
            return BuildStep(kind: shares ? .inOrder : .together, tasks: group)
        }
    }
}

/// What the user did with one task on V2-3. A task with no run is ready to start, or waiting.
public struct TaskRun: Codable, Hashable, Sendable {
    public enum State: String, Codable, Sendable {
        /// Its prompt was copied; Claude Code is working on it.
        case running
        case failed
        /// The check passed, or the user marked it done without one (`checked == false`).
        case done
    }

    public var state: State
    /// When the check passed or the task was marked done.
    public var at: Date?
    /// Done by hand, without running the check.
    public var byHand = false
    /// The end of the failing check's output, for the card and the fix prompt.
    public var output: String?

    public init(state: State, at: Date? = nil, byHand: Bool = false, output: String? = nil) {
        self.state = state
        self.at = at
        self.byHand = byHand
        self.output = output
    }
}

/// A task as V2-3 shows it.
public enum TaskStatus: Hashable, Sendable {
    /// Its step hasn't opened yet, or the task before it in a one-after-the-other step isn't done.
    case waiting(String)
    case ready
    case running
    case failed(String)
    case done(TaskRun)
}

extension Spec {
    /// Where `task` stands, given the runs so far.
    public func status(of task: SpecTask, in steps: [BuildStep]) -> TaskStatus {
        if let run = runs?[task.number] {
            switch run.state {
            case .running: return .running
            case .failed: return .failed(run.output ?? "")
            case .done: return .done(run)
            }
        }
        guard let index = steps.firstIndex(where: { $0.tasks.contains(task) }) else { return .ready }
        if index > 0, !isDone(steps[index - 1]) { return .waiting("Starts after step \(index) is done.") }
        let step = steps[index]
        if step.kind == .inOrder, let position = step.tasks.firstIndex(of: task), position > 0 {
            let before = step.tasks[position - 1]
            if runs?[before.number]?.state != .done {
                let shared = Set(before.changes).intersection(task.changes).sorted()
                return .waiting("Starts after task \(before.number)." + (shared.isEmpty ? "" : " Both change \(shared.joined(separator: ", "))."))
            }
        }
        return .ready
    }

    public func isDone(_ step: BuildStep) -> Bool {
        step.tasks.allSatisfy { runs?[$0.number]?.state == .done }
    }

    /// Done tasks out of `tasks`.
    public func doneCount(_ tasks: [SpecTask]) -> Int {
        tasks.count { runs?[$0.number]?.state == .done }
    }

    /// Copy prompt: Claude Code is on it.
    public mutating func started(_ task: Int) {
        runs = (runs ?? [:]).merging([task: TaskRun(state: .running)]) { _, new in new }
        if build == nil || build == .done { build = .building }
    }

    /// The check's result, or "Mark done without the check". The last task done moves the spec to Done.
    public mutating func finished(_ task: Int, passed: Bool, output: String = "", byHand: Bool = false, at date: Date = .now, of tasks: [SpecTask]) {
        runs = (runs ?? [:]).merging([task: passed ? TaskRun(state: .done, at: date, byHand: byHand) : TaskRun(state: .failed, output: output)]) { _, new in new }
        build = !tasks.isEmpty && doneCount(tasks) == tasks.count ? .done : .building
    }

    /// Reopen on a done task.
    public mutating func reopen(_ task: Int) {
        runs?[task] = nil
        if build == .done { build = .building }
    }

    /// "Start over" once everything is built.
    public mutating func startOver() {
        runs = nil
        build = .building
    }
}

extension SpecTask {
    /// Copy prompt (V2-3): short, naming only the passages the task needs; AGENTS.md says where the spec is.
    public func buildPrompt(slug: String, of total: Int) -> String {
        var lines = ["Task \(number) of \(total) in specs/\(slug).",
                     reads.isEmpty ? "Read AGENTS.md first." : "Read AGENTS.md first, then only: \(reads).",
                     "Build: \(title)" + (covers.isEmpty ? "." : " (requirements \(covers.joined(separator: ", "))).")]
        if !changes.isEmpty { lines.append("Change only \(changes.joined(separator: ", ")).") }
        if !verify.isEmpty { lines.append("Done when this passes: \(verify)") }
        lines.append("If the plan doesn’t fit what you find, stop and say why instead of changing the plan.")
        return lines.joined(separator: "\n")
    }

    /// Copy fix prompt: the failing check and its output.
    public func fixPrompt(slug: String, of total: Int, output: String) -> String {
        ["Task \(number) of \(total) in specs/\(slug): the check failed.", verify, output,
         "Fix the code" + (changes.isEmpty ? "" : " in \(changes.joined(separator: ", "))") + " so the check passes. Don’t change the tests or the plan."]
            .filter { !$0.isEmpty }
            .joined(separator: "\n")
    }
}
