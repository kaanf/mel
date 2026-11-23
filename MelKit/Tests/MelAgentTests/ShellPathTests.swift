import Foundation
import Testing
@testable import MelAgent

struct ShellPathTests {
    @Test func findsInExtraPaths() async {
        #expect(await ShellPath.find("sh", extraPaths: ["/bin"])?.path == "/bin/sh")
    }

    @Test func missingExecutable() async {
        #expect(await ShellPath.find("mel-no-such-tool", extraPaths: ["/bin"]) == nil)
    }
}
