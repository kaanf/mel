import Foundation
import Testing
import MelAgent
import MelSpec
import MelSystem
@testable import Mel

/// The whole product with the real Claude Code, from an idea to built code: project context, intake,
/// the files, the check, Start Building, then every task run in Mel. Opt-in, since it spends real
/// tokens: `TEST_RUNNER_MEL_REAL_RUN=1 TEST_RUNNER_MEL_REAL_RUN_DIR=<folder> xcodebuild test -only-testing:MelTests/RealRunTests`.
/// Writes `report.md` and keeps the repo in that folder for a look afterwards.
@MainActor
@Suite(.enabled(if: ProcessInfo.processInfo.environment["MEL_REAL_RUN"] == "1"))
final class RealRunTests {
    private var log: [String] = []
    private let started = Date.now

    private func note(_ line: String) {
        log.append(String(format: "[%5.0fs] ", Date.now.timeIntervalSince(started)) + line)
    }

    @Test func ideaToBuiltCode() async throws {
        let root = URL(filePath: ProcessInfo.processInfo.environment["MEL_REAL_RUN_DIR"] ?? NSTemporaryDirectory()).appending(path: "mel-real-\(Int(started.timeIntervalSince1970))", directoryHint: .isDirectory)
        let folder = root.appending(path: "tip-calc", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try "# tip-calc\n\nSmall POSIX shell tools. Scripts live in bin/, tests in tests/.\n".write(to: folder.appending(path: "README.md"), atomically: true, encoding: .utf8)
        for arguments in [["init", "--quiet", "-b", "main"], ["add", "-A"], ["commit", "--quiet", "-m", "Start"]] { try git(folder, arguments) }
        defer { try? (log.joined(separator: "\n") + "\n").write(to: root.appending(path: "report.md"), atomically: true, encoding: .utf8) }

        let app = AppState(adapter: ClaudeCode(), makeRunner: { AgentRunner(adapter: ClaudeCode(), executable: $0) },
                           defaults: UserDefaults(suiteName: "mel-real-\(UUID().uuidString)")!)
        app.notify = { [unowned self] title, body, _ in note("notification: \(title) · \(body)") }
        app.authorizeNotifications = {}
        await app.scanForAgent()
        note("agent: \(app.agent.word) · models \(app.writingModel.name) / \(app.quickModel.name)")
        try #require(app.agent.isReady)

        // Start: the project, read once in the background.
        let project = try app.addProject(folder)
        await app.readContext(of: project)
        note("project context: \(app.contextErrors[project.id] ?? "read") · modules \(app.contexts[project.id]?.modules.count ?? 0)")

        // New: one box, size Feature.
        let idea = "A command-line script bin/tip.sh that takes a bill amount and a tip percent and prints the tip and the total with two decimals. A negative or non-numeric amount gets a clear error and exit code 1. Plain POSIX sh, tested by tests/test.sh."
        let session = try app.createSpec(name: "", idea: idea, size: .feature, project: project)
        await session.start()
        note("intake: \(session.spec.name) · \(session.spec.questions.count) questions")
        var guardCount = 0
        while let card = session.spec.intakeCard, guardCount < 10 {
            guardCount += 1
            let pick = card.options.firstIndex { $0.suggested } ?? 0
            note("  Q: \(card.text) → \(card.options.indices.contains(pick) ? card.options[pick].label : "?")")
            await session.answerIntake(.option(pick, note: nil))
        }
        try expectNoError(session, "intake")

        // The board: each file's cards answered with the suggested option, until the plan is ready.
        guardCount = 0
        while !session.spec.isReady, guardCount < 20 {
            guardCount += 1
            if session.spec.halted != nil || session.spec.unplacedChange != nil {
                note("board stopped: \(session.spec.halted.map { "\($0.reason)" } ?? "unplaced change") · \(session.lastError ?? "")")
                break
            }
            if let card = session.spec.openCards.first {
                let pick = card.options.firstIndex { $0.suggested } ?? 0
                note("  card (\(card.file?.fileName ?? "check")): \(card.text) → \(card.options.indices.contains(pick) ? card.options[pick].label : "?")")
                await session.answerCard(card.id, .option(pick, note: nil))
            } else {
                await session.continueBoard()
            }
        }
        for kind in session.spec.size.files {
            note("\(kind.fileName): \(session.documents[kind]?.count ?? 0) characters")
        }
        note("plan ready: \(session.spec.isReady) · check \(session.spec.analyze)")
        note("spec tokens: " + session.spec.tokenSteps.map { "\($0.step.title) \(TokenStep.text($0.tokens))" }.joined(separator: ", ") + " · total \(TokenStep.text(session.spec.tokenTotal))")
        try #require(session.spec.isReady)

        // Build: every task run in Mel, in order; a question gets the suggested answer.
        try await session.startBuilding(commitToGit: true, writeAgentsFile: true)
        note("tasks: " + session.tasks.map { "\($0.number). \($0.title) [\($0.phase)] changes \($0.changes) verify `\($0.verify)`" }.joined(separator: " | "))
        for task in session.tasks {
            var rounds = 0
            while rounds < 4 {
                rounds += 1
                switch session.status(of: task) {
                case .ready, .stopped:
                    let start = Date.now
                    await session.run(task)
                    note("task \(task.number) run: \(Int(Date.now.timeIntervalSince(start)))s · \(session.activity.count) steps · \(session.lastError ?? "no error")")
                case .asking(let question):
                    let pick = question.options.first { $0.suggested } ?? question.options.first
                    note("task \(task.number) asks: \(question.title) → \(pick?.label ?? "-")")
                    await session.answer(task, with: pick?.label ?? "Pick the simplest")
                case .running:
                    note("task \(task.number): no commit found after its run (uncommitted: \(session.uncommitted.contains(task.number)))")
                    rounds = 99
                case .failed(let output):
                    note("task \(task.number): check failed\n\(output)")
                    rounds = 99
                case .waiting(let why):
                    note("task \(task.number): waiting · \(why)")
                    rounds = 99
                case .done:
                    rounds = 99
                }
            }
            let run = session.spec.runs?[task.number]
            note("task \(task.number) → \(session.status(of: task)) · tokens \(run?.tokens.map(TokenStep.text) ?? "-")")
            if let report = run?.report {
                note("  works: \(report.works)")
                note("  decisions: \(report.decisions.map { "\($0.title) (\($0.why); instead \($0.instead))" })")
                note("  not done: \(report.notDone) · refused: \(report.refused)")
            }
            guard case .done = session.status(of: task) else { break }
        }

        note("built: \(session.spec.build.map { "\($0)" } ?? "-") · \(session.spec.doneCount(session.tasks)) of \(session.tasks.count) tasks")
        note("tokens: " + session.spec.tokenSteps.map { "\($0.step.title) \(TokenStep.text($0.tokens))" }.joined(separator: ", ") + " · total \(TokenStep.text(session.spec.tokenTotal))")
        note("branch: \(Git.branch(at: folder) ?? "-")")
        note("git log:\n" + output(folder, ["log", "--format=%h %d %s", "--all"]))
        note("repo: \(folder.path(percentEncoded: false))")
        #expect(session.spec.build == .done)
    }

    private func expectNoError(_ session: SpecSession, _ step: String) throws {
        if let error = session.lastError { note("\(step) error: \(error)") }
    }

    private func output(_ repo: URL, _ arguments: [String]) -> String {
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = arguments
        process.currentDirectoryURL = repo
        process.standardOutput = pipe
        try? process.run()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return String(decoding: data, as: UTF8.self)
    }

    private func git(_ repo: URL, _ arguments: [String]) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = ["-c", "user.name=Mel Tests", "-c", "user.email=tests@example.com"] + arguments
        process.currentDirectoryURL = repo
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try process.run()
        process.waitUntilExit()
    }
}
