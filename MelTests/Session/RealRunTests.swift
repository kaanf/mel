import Foundation
import Testing
import MelAgent
import MelSpec
import MelStorage
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
        note("agent: \(app.agent.word) · models \(ModelStep.allCases.map { "\($0.title) \(app.model(for: $0).name)" }.joined(separator: ", ")), project context Haiku 5.5")
        try #require(app.agent.isReady)

        // Start: the project, read once in the background.
        let project = try app.addProject(folder)
        await app.readContext(of: project)
        note("project context: \(app.contextErrors[project.id] ?? "read") · modules \(app.contexts[project.id]?.modules.count ?? 0)")

        // New: one box, size Feature.
        let idea = "A command-line script bin/tip.sh that takes a bill amount and a tip percent and prints the tip and the total with two decimals. A negative or non-numeric amount gets a clear error and exit code 1. Plain POSIX sh, tested by tests/test.sh."
        let session = try app.createSpec(name: Spec.untitledName, idea: idea, size: .feature, project: project)
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
        // Wave 10: WHEN/THEN criteria with their tags, and the architecture's diagram.
        let criteria = MarkdownParser.blocks(session.documents[.requirements] ?? "").compactMap { block -> String? in
            if case .criterion(let id, let text) = block { "\(id) \(text)" } else { nil }
        }
        note("criteria: \(criteria.count), WHEN/THEN \(criteria.count { $0.contains(" THEN ") }), tagged \(criteria.count { ProjectSpec.tag(of: String($0.drop { $0 != " " }.dropFirst())) != nil })")
        note("  e.g. \(criteria.prefix(2))")
        let diagrams = MarkdownParser.blocks(session.documents[.architecture] ?? "").compactMap { block -> String? in if case .diagram(let text) = block { text } else { nil } }
        note("diagrams: \(diagrams.count), drawn \(diagrams.count { Flowchart.parse($0) != nil })")
        note("project spec: \(ProjectStore.readProjectSpec(project: folder).map { "\($0.areas.count) areas, \($0.areas.reduce(0) { $0 + $1.rules.count }) rules" } ?? "none")")
        note("plan ready: \(session.spec.isReady) · check \(session.spec.analyze)")
        note("spec tokens: " + session.spec.tokenSteps.map { "\($0.step.title) \(TokenStep.text($0.tokens))" }.joined(separator: ", ") + " · total \(TokenStep.text(session.spec.tokenTotal))")
        try #require(session.spec.isReady)

        // Build: every task run in Mel, in order; a question gets the suggested answer.
        try await session.startBuilding(commitToGit: true, writeAgentsFile: true)
        note("tasks: " + session.tasks.map { "\($0.number). \($0.title) [\($0.phase)] changes \($0.changes) verify `\($0.verify)`" }.joined(separator: " | "))
        // Run the rest, answering each question with the suggested option, until it stops for another reason.
        for _ in 0..<8 {
            let start = Date.now
            await session.runRest()
            note("run the rest: \(Int(Date.now.timeIntervalSince(start)))s · \(session.lastError ?? "no error")")
            guard let (task, question) = session.tasks.lazy.compactMap({ task -> (SpecTask, BuildQuestion)? in
                if case .asking(let question) = session.status(of: task) { (task, question) } else { nil }
            }).first else { break }
            let pick = question.options.first { $0.suggested } ?? question.options.first
            note("task \(task.number) asks: \(question.title) → \(pick?.label ?? "-")")
            await session.answer(task, with: pick?.label ?? "Pick the simplest")
        }
        for task in session.tasks {
            let run = session.spec.runs?[task.number]
            note("task \(task.number) → \(session.status(of: task)) · tokens \(run?.tokens.map(TokenStep.text) ?? "-")")
            if let report = run?.report {
                note("  works: \(report.works)")
                note("  decisions: \(report.decisions.map { "\($0.title) (\($0.why); instead \($0.instead))" })")
                note("  not done: \(report.notDone) · refused: \(report.refused)")
            }
        }

        // V2-34 before merging: the spec's tagged criteria into specs/current/, committed on the spec branch.
        await session.refreshProjectSpecChanges()
        note("project spec changes: \(session.projectSpecChanges.map { "\($0.kind) \($0.id) \($0.file)" })")
        await session.updateProjectSpec()
        note("project spec updated: \(session.spec.projectSpec.map { "\($0)" } ?? "-") · \(session.lastError ?? "no error")")
        // Merge into main after main moved: the same script added there differently, so it conflicts.
        if session.spec.build == .done, let script = session.tasks.flatMap(\.changes).first(where: { $0.hasPrefix("bin") }) {
            try git(folder, ["checkout", "--quiet", "main"])
            // A task's Changes may name the file itself (bin/tip.sh) or its folder (bin).
            let file = script.hasSuffix(".sh") ? folder.appending(path: script) : folder.appending(path: script).appending(path: "tip.sh")
            try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
            try "#!/bin/sh\n# Placeholder from main: prints usage.\necho 'usage: tip.sh AMOUNT PERCENT'\n".write(to: file, atomically: true, encoding: .utf8)
            try git(folder, ["add", "-A"])
            try git(folder, ["commit", "--quiet", "-m", "chore: usage placeholder on main"])
            try git(folder, ["checkout", "--quiet", session.branch])
            await session.mergeIntoMain()
            note("merge: conflict \(session.mergeConflict?.files ?? []) · about \(session.mergeConflict.map { TokenStep.text($0.tokens) } ?? "-") tokens · \(session.lastError ?? "no error")")
            if session.mergeConflict != nil {
                let before = session.spec.tokens?[.build] ?? 0
                let start = Date.now
                await session.resolveConflict()
                note("resolve: \(Int(Date.now.timeIntervalSince(start)))s · \(TokenStep.text((session.spec.tokens?[.build] ?? 0) - before)) tokens · \(session.lastError ?? "no error") · works \(session.resolveReport?.works ?? []) · refused \(session.resolveReport?.refused ?? [])")
                await session.mergeIntoMain()
            }
            note("merged into: \(session.spec.mergedInto ?? "-") · \(session.lastError ?? "no error")")
            if let check = session.tasks.last?.verify, !check.isEmpty {
                let result = await app.runCheck(check, folder)
                note("last task's check on main: \(result.passed ? "passed" : "failed\n" + result.output)")
            }
        }

        note("built: \(session.spec.build.map { "\($0)" } ?? "-") · \(session.spec.doneCount(session.tasks)) of \(session.tasks.count) tasks")
        note("tokens: " + session.spec.tokenSteps.map { "\($0.step.title) \(TokenStep.text($0.tokens))" }.joined(separator: ", ") + " · total \(TokenStep.text(session.spec.tokenTotal))")
        note("branch: \(Git.branch(at: folder) ?? "-")")
        note("git log:\n" + output(folder, ["log", "--format=%h %d %s", "--all"]))
        note("repo: \(folder.path(percentEncoded: false))")
        #expect(session.spec.build == .done)
        #expect(session.spec.mergedInto == "main")
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
