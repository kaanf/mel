import Foundation
import Testing
@testable import MelSystem

struct CheckTests {
    let folder = FileManager.default.temporaryDirectory

    @Test func passesOnExitZeroAndKeepsTheOutputsEnd() async {
        let result = await Check.run("for i in $(seq 1 30); do echo line $i; done", in: folder)
        #expect(result.passed)
        #expect(result.output.hasSuffix("line 30"))
        #expect(result.output.split(separator: "\n").count == Check.tailLines)
    }

    @Test func failsWithStderrInTheOutput() async {
        let result = await Check.run("echo 'Test > receipt FAILED' >&2; exit 1", in: folder)
        #expect(!result.passed)
        #expect(result.output.contains("Test > receipt FAILED"))
    }

    @Test func runsInTheProjectFolder() async {
        let result = await Check.run("pwd", in: folder)
        #expect(result.output.contains(folder.resolvingSymlinksInPath().path.split(separator: "/").last ?? ""))
    }
}
