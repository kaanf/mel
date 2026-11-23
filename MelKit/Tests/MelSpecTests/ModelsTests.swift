import Foundation
import Testing
@testable import MelSpec

struct ModelsTests {
    @Test func docKindFileName() {
        #expect(DocKind.allCases.map(\.fileName) == ["PRODUCT.md", "REQUIREMENTS.md", "EXPERIENCE.md", "ARCHITECTURE.md", "TASKS.md", "SPEC.md"])
        #expect(DocKind.requirements.title == "Requirements")
    }

    @Test func sizeFixesFilesAndOrder() {
        #expect(SpecSize.quickFix.files == [.spec])
        #expect(SpecSize.feature.files == [.requirements, .architecture, .tasks])
        #expect(SpecSize.product.files == [.product, .requirements, .experience, .architecture, .tasks])
        #expect(SpecSize.feature.file(after: .requirements) == .architecture)
        #expect(SpecSize.feature.file(after: .tasks) == nil)
        #expect(Spec(name: "Fix", idea: "x", size: .quickFix, folder: URL(filePath: "/p/specs/fix")).docs == [.spec: .locked])
        #expect(Spec(name: "Fix", idea: "x", folder: URL(filePath: "/p/specs/fix/")).project.path == "/p")
    }

    @Test func projectFoldersCompareEqualHoweverTheyAreWritten() throws {
        let real = FileManager.default.temporaryDirectory.appending(path: "mel-norm-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: real, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: real) }
        let link = real.deletingLastPathComponent().appending(path: "link-\(UUID().uuidString)")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: real)
        defer { try? FileManager.default.removeItem(at: link) }

        let noSlash = URL(filePath: String(real.path(percentEncoded: false).dropLast()))   // "…/mel-norm-…"
        let spec = Spec(name: "S", idea: "x", folder: real.appending(path: "specs/s", directoryHint: .isDirectory))
        #expect(spec.project == Project(folder: noSlash).folder)
        #expect(Project(folder: real).id == Project(folder: noSlash).id)
        #expect(Project(folder: link).id == Project(folder: real).id)
        #expect(URL(filePath: "/tmp/x").normalizedFolder == URL(filePath: "/private/tmp/x/").normalizedFolder)
    }

    @Test func v2SpecRoundTrips() throws {
        var spec = Spec(name: "Booking", idea: "x", size: .feature, folder: URL(filePath: "/p/specs/booking"), buildsOn: ["Booking"], attachments: [Attachment(fileName: "log-1.txt")], analyze: .issues(2))
        spec.docs[.architecture] = .stale
        spec.questions = [Question(id: "q", title: "Offline?", why: "", shapes: .requirements, round: .draft, options: [])]
        #expect(try JSONDecoder().decode(Spec.self, from: JSONEncoder().encode(spec)) == spec)
    }

    @Test func stateFromBeforePhasesLoadsCoverageAsProduct() throws {
        let old = #"{"label":"Payments","state":"covered"}"#
        #expect(try JSONDecoder().decode(CoverageItem.self, from: Data(old.utf8)) == CoverageItem(label: "Payments", phase: .product, state: .covered))
        let item = CoverageItem(label: "Screens", phase: .architecture, state: .asking)
        #expect(try JSONDecoder().decode(CoverageItem.self, from: JSONEncoder().encode(item)) == item)
    }

    @Test func textAnswerRoundTrips() throws {
        let answer = Answer.text("Calm, like Things.")
        #expect(try JSONDecoder().decode(Answer.self, from: JSONEncoder().encode(answer)) == answer)
    }
}
