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
        /// A run in Mel was stopped: its changes aren't committed until the user keeps or undoes them (V2-21).
        case stopped
    }

    public var state: State
    /// When the check passed or the task was marked done.
    public var at: Date?
    /// Done by hand, without running the check.
    public var byHand = false
    /// The end of the failing check's output, for the card and the fix prompt.
    public var output: String?
    /// The task's prompt when it was copied or marked done. A Tell Mel change that makes it differ
    /// shows "Prompt changed" or "Changed after done" (V2-13).
    public var prompt: String?
    /// HEAD when the prompt was first copied: the task is done only once git shows its folders changed since.
    public var base: String?
    /// Run in Mel (V2-17): its Claude Code session, what it said it did, and the tokens it used.
    public var session: String?
    public var report: BuildReport?
    public var tokens: Int?
    /// The question the run stopped on, until the user answers it (V2-18).
    public var question: BuildQuestion?

    public init(state: State, at: Date? = nil, byHand: Bool = false, output: String? = nil, prompt: String? = nil, base: String? = nil) {
        self.state = state
        self.at = at
        self.byHand = byHand
        self.output = output
        self.prompt = prompt
        self.base = base
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
    /// Stopped in Mel, its changes not committed: Keep or Undo.
    case stopped
    /// A run in Mel stopped on a question for the user (V2-18).
    case asking(BuildQuestion)
}

extension Spec {
    /// Where `task` stands, given the runs so far.
    public func status(of task: SpecTask, in steps: [BuildStep]) -> TaskStatus {
        if let run = runs?[task.number] {
            switch run.state {
            case .running: return run.question.map { .asking($0) } ?? .running
            case .failed: return .failed(run.output ?? "")
            case .done: return .done(run)
            case .stopped: return .stopped
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

    /// Copy prompt: Claude Code is on it, with `prompt`. A fix prompt keeps the first copy's commit.
    public mutating func started(_ task: Int, prompt: String) {
        runs = (runs ?? [:]).merging([task: TaskRun(state: .running, prompt: prompt, base: runs?[task]?.base)]) { _, new in new }
        if build == nil || build == .done { build = .building }
    }

    /// The check's result, or "Mark done without the check". The run keeps the prompt that was
    /// copied; `prompt` is the current one, for a task never copied. The last task done moves the spec to Done.
    public mutating func finished(_ task: Int, passed: Bool, output: String = "", byHand: Bool = false, at date: Date = .now, prompt: String, of tasks: [SpecTask]) {
        let old = runs?[task]
        var run = passed ? TaskRun(state: .done, at: date, byHand: byHand, prompt: old?.prompt ?? prompt, base: old?.base)
                         : TaskRun(state: .failed, output: output, prompt: old?.prompt ?? prompt, base: old?.base)
        (run.session, run.report, run.tokens) = (old?.session, old?.report, old?.tokens)
        runs = (runs ?? [:]).merging([task: run]) { _, new in new }
        retasked(tasks)
    }

    /// TASKS.md changed while building: a task added to a finished build reopens it, and the reverse.
    public mutating func retasked(_ tasks: [SpecTask]) {
        taskCount = tasks.count
        build = !tasks.isEmpty && doneCount(tasks) == tasks.count ? .done : .building
    }

    /// The commit HEAD was on when `task`'s prompt was first copied.
    public mutating func based(_ task: Int, on commit: String) {
        guard runs?[task] != nil, runs?[task]?.base == nil else { return }
        runs?[task]?.base = commit
    }

    /// The prompt the user ran is no longer the task's prompt.
    public func promptChanged(_ task: Int, now prompt: String) -> Bool {
        guard let copied = runs?[task]?.prompt else { return false }
        return copied != prompt
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
    /// The line that ties a commit to this task; Check it and Mark done look for it in git.
    public func trailer(slug: String) -> String { "Mel-Task: \(slug)/\(number)" }

    /// Copy prompt (V2-3): short, naming only the passages the task needs; AGENTS.md says where the spec is.
    public func buildPrompt(slug: String, of total: Int) -> String {
        var lines = ["Task \(number) of \(total) in specs/\(slug).",
                     reads.isEmpty ? "Read AGENTS.md first." : "Read AGENTS.md first, then only: \(reads).",
                     "Build: \(title)" + (covers.isEmpty ? "." : " (requirements \(covers.joined(separator: ", "))).")]
        if !changes.isEmpty { lines.append("Change only \(changes.joined(separator: ", ")).") }
        if !verify.isEmpty { lines.append("Done when this passes: \(verify)") }
        lines.append("When it's done, commit with a Conventional Commits message (feat:, fix: …) whose last line is: \(trailer(slug: slug))")
        lines.append("If the plan doesn’t fit what you find, stop and say why instead of changing the plan.")
        return lines.joined(separator: "\n")
    }

    /// Run (V2-17): the Copy prompt plus when to ask and the report's shape (OQ #42: a few lines, no spec files).
    public func runPrompt(slug: String, of total: Int) -> String {
        buildPrompt(slug: slug, of: total) + """


        Rules for this run:
        - Don't ask how to build it: the spec and AGENTS.md decide. Where they are silent, pick the simplest choice that fits and list it under decisions.
        - Stop to ask only when the choice changes what users see or is hard to undo. Then end your reply with this instead, and nothing after it:
        {"question":{"title":"the question, in plain words","why":"why it matters","options":[{"label":"","means":"what it means for users","suggested":true}]}}
        - You may change files only in the task's folders, run its check and commit. Anything else is refused; list it under refused.
        - Otherwise end your reply with one JSON object and nothing after it, written for someone who doesn't code:
        {"works":["what a user can do now, one plain sentence each"],"decisions":[{"title":"","why":"","instead":"the alternative and what it would mean"}],"notDone":[""],"refused":[""]}
        """
    }

    /// The answer to a question a run stopped on (V2-18); the run goes on in the same session.
    public func answerPrompt(_ answer: String) -> String {
        """
        My answer: \(answer)
        Go on with task \(number) from where you stopped. End with the JSON report (or another question), as before.
        """
    }

    /// Copy fix prompt: the failing check and its output.
    public func fixPrompt(slug: String, of total: Int, output: String) -> String {
        ["Task \(number) of \(total) in specs/\(slug): the check failed.", verify, output,
         "Fix the code" + (changes.isEmpty ? "" : " in \(changes.joined(separator: ", "))") + " so the check passes. Don’t change the tests or the plan.",
         "Commit the fix with a Conventional Commits message whose last line is: \(trailer(slug: slug))"]
            .filter { !$0.isEmpty }
            .joined(separator: "\n")
    }
}

/// What a task run in Mel says it did (V2-19), from the JSON object at the end of its reply.
public struct BuildReport: Codable, Hashable, Sendable {
    public struct Decision: Codable, Hashable, Sendable {
        public var title: String
        public var why: String
        public var instead: String

        public init(title: String, why: String, instead: String) {
            (self.title, self.why, self.instead) = (title, why, instead)
        }
    }

    public var works: [String]
    public var decisions: [Decision]
    public var notDone: [String]
    public var refused: [String]

    public init(works: [String] = [], decisions: [Decision] = [], notDone: [String] = [], refused: [String] = []) {
        (self.works, self.decisions, self.notDone, self.refused) = (works, decisions, notDone, refused)
    }

    /// The last `{"works"…}` object in the reply; prose and a code fence around it are ignored. Nil when there is none.
    public static func parse(_ reply: String) -> BuildReport? {
        guard let start = reply.range(of: #"{"works""#, options: .backwards) ?? reply.range(of: #"{ "works""#, options: .backwards),
              let data = try? jsonObject(in: String(reply[start.lowerBound...])),
              let raw = try? JSONDecoder().decode(Raw.self, from: data) else { return nil }
        let clean = { (lines: [String]?) in (lines ?? []).map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty } }
        return BuildReport(works: clean(raw.works),
                           decisions: (raw.decisions ?? []).filter { !$0.title.isEmpty },
                           notDone: clean(raw.notDone), refused: clean(raw.refused))
    }

    private struct Raw: Decodable {
        var works: [String]?
        var decisions: [Decision]?
        var notDone: [String]?
        var refused: [String]?
    }
}

/// A question a task run in Mel stopped on, asked only about what users see or what is hard to undo (V2-18).
public struct BuildQuestion: Codable, Hashable, Sendable {
    public struct Option: Codable, Hashable, Sendable {
        public var label: String
        public var means: String
        public var suggested: Bool

        public init(label: String, means: String = "", suggested: Bool = false) {
            (self.label, self.means, self.suggested) = (label, means, suggested)
        }
    }

    public var title: String
    public var why: String
    public var options: [Option]

    public init(title: String, why: String = "", options: [Option] = []) {
        (self.title, self.why, self.options) = (title, why, options)
    }

    /// The last `{"question"…}` object in the reply; nil when the run ended with its report.
    public static func parse(_ reply: String) -> BuildQuestion? {
        guard let start = reply.range(of: #"{"question""#, options: .backwards) ?? reply.range(of: #"{ "question""#, options: .backwards),
              let data = try? jsonObject(in: String(reply[start.lowerBound...])),
              let raw = try? JSONDecoder().decode(Raw.self, from: data), !raw.question.title.isEmpty else { return nil }
        return BuildQuestion(title: raw.question.title, why: raw.question.why ?? "",
                             options: (raw.question.options ?? []).filter { !$0.label.isEmpty }.map { Option(label: $0.label, means: $0.means ?? "", suggested: $0.suggested ?? false) })
    }

    private struct Raw: Decodable {
        struct Question: Decodable { var title: String; var why: String?; var options: [RawOption]? }
        struct RawOption: Decodable { var label: String; var means: String?; var suggested: Bool? }
        var question: Question
    }
}
