import Foundation
import Testing
@testable import MelSpec

struct PipelineTests {
    private func spec() -> Spec {
        Spec(name: "Yoga", idea: "Book classes", folder: URL(filePath: "/tmp/yoga/specs"))
    }

    /// A spec in review of `kind`, with every earlier file approved.
    private func inReview(_ kind: DocKind) -> Spec {
        var s = spec()
        s.apply(.discoveryFinished)
        for k in DocKind.allCases {
            s.apply(.draftFinished)
            if k == kind { return s }
            s.apply(.approve(k, assumptionsLeft: 0))
        }
        fatalError()
    }

    @Test func newSpecStartsInDiscoveryWithFilesLocked() {
        let s = spec()
        #expect(s.stage == .discovery)
        #expect(s.size.files.allSatisfy { s.docs[$0] == .locked })
    }

    @Test func discoveryFinishedStartsProduct() {
        var s = spec()
        do { let applied = s.apply(.discoveryFinished); #expect(applied) }
        #expect(s.stage == .drafting(.product))
        #expect(s.docs[.product] == .writing)
    }

    @Test func draftFinishedMovesToReview() {
        var s = spec()
        s.apply(.discoveryFinished)
        do { let applied = s.apply(.draftFinished); #expect(applied) }
        #expect(s.stage == .review(.product))
        #expect(s.docs[.product] == .review)
    }

    @Test func stopThenResume() {
        var s = spec()
        s.apply(.discoveryFinished)
        do { let applied = s.apply(.draftStopped(.usageLimit(resetsAt: nil))); #expect(applied) }
        #expect(s.stage == .stopped(.product, .usageLimit(resetsAt: nil)))
        #expect(s.docs[.product] == .stopped)
        do { let applied = s.apply(.resume); #expect(applied) }
        #expect(s.stage == .drafting(.product))
        #expect(s.docs[.product] == .writing)
    }

    @Test func stopThenFinishByHand() {
        var s = spec()
        s.apply(.discoveryFinished)
        s.apply(.draftStopped(.user))
        do { let applied = s.apply(.finishByHand); #expect(applied) }
        #expect(s.stage == .review(.product))
        #expect(s.docs[.product] == .review)
    }

    @Test func approveStartsNextFile() {
        var s = inReview(.product)
        do { let applied = s.apply(.approve(.product, assumptionsLeft: 0)); #expect(applied) }
        #expect(s.docs[.product] == .approved)
        #expect(s.stage == .drafting(.requirements))
        #expect(s.docs[.requirements] == .writing)
        #expect(s.docs[.architecture] == .locked)
    }

    @Test func approveBlockedWhileAssumptionsRemain() {
        var s = inReview(.product)
        let before = s
        do { let applied = s.apply(.approve(.product, assumptionsLeft: 2)); #expect(!applied) }
        #expect(s == before)
    }

    @Test func approvingTasksFinishes() {
        var s = inReview(.tasks)
        do { let applied = s.apply(.approve(.tasks, assumptionsLeft: 0)); #expect(applied) }
        #expect(s.stage == .done)
        #expect(s.size.files.allSatisfy { s.docs[$0] == .approved })
    }

    @Test func editingApprovedFileReturnsItToReviewOnly() {
        var s = inReview(.architecture)
        do { let applied = s.apply(.edited(.product)); #expect(applied) }
        #expect(s.docs[.product] == .review)
        #expect(s.stage == .review(.architecture))
        #expect(s.docs[.requirements] == .approved)

        // Re-approving it doesn't move the pipeline.
        do { let applied = s.apply(.approve(.product, assumptionsLeft: 0)); #expect(applied) }
        #expect(s.docs[.product] == .approved)
        #expect(s.stage == .review(.architecture))
    }

    @Test func editingAFileInReviewChangesNothing() {
        var s = inReview(.product)
        do { let applied = s.apply(.edited(.product)); #expect(!applied) }
        #expect(s.docs[.product] == .review)
    }

    @Test func eventsOutOfOrderAreRejected() {
        var s = spec()
        let before = s
        do { let applied = s.apply(.draftFinished); #expect(!applied) }
        do { let applied = s.apply(.resume); #expect(!applied) }
        do { let applied = s.apply(.finishByHand); #expect(!applied) }
        do { let applied = s.apply(.approve(.product, assumptionsLeft: 0)); #expect(!applied) }
        #expect(s == before)

        s.apply(.discoveryFinished)
        do { let applied = s.apply(.discoveryFinished); #expect(!applied) }
        do { let applied = s.apply(.resume); #expect(!applied) }
        do { let applied = s.apply(.approve(.product, assumptionsLeft: 0)); #expect(!applied) }
    }

    @Test func specRoundTripsThroughJSON() throws {
        var s = inReview(.requirements)
        s.apply(.edited(.product))
        s.questions = [Question(id: "pay", title: "How?", why: "Scope", shapes: .requirements,
                                options: [Option(label: "Packs", note: "", suggested: true)], answer: .option(0, note: "cheap"))]
        s.coverage = [CoverageItem(label: "Payments", state: .covered)]
        let decoded = try JSONDecoder().decode(Spec.self, from: JSONEncoder().encode(s))
        #expect(decoded == s)
    }
}
