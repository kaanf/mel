import Foundation
import Testing
@testable import MelSpec

struct PipelineTests {
    private func spec(_ size: SpecSize = .product) -> Spec {
        Spec(name: "Yoga", idea: "Book classes", size: size, folder: URL(filePath: "/tmp/yoga/specs/yoga"))
    }

    /// A spec in review of `kind`, with every earlier file approved.
    private func inReview(_ kind: DocKind, _ size: SpecSize = .product) -> Spec {
        var s = spec(size)
        s.apply(.discoveryFinished)
        for k in size.files {
            s.apply(.draftFinished)
            if k == kind { return s }
            s.apply(.approve(k))
        }
        fatalError()
    }

    /// Every file approved, Analyze back with `issues` issues.
    private func analyzed(_ issues: Int = 0) -> Spec {
        var s = inReview(.tasks)
        s.apply(.approve(.tasks))
        s.apply(.analyzeFinished(result(issues)))
        return s
    }

    private func allApproved(_ s: Spec) -> Bool { s.size.files.allSatisfy { s.docs[$0] == .approved } }

    private func result(_ issues: Int) -> AnalyzeResult {
        let issue = AnalyzeResult.Issue(id: "i", kind: .noTask, location: "REQUIREMENTS 2.2", text: "No task.", actions: [])
        return AnalyzeResult(stats: [], issues: Array(repeating: issue, count: issues), coverage: [])
    }

    @Test func newSpecStartsInDiscoveryWithItsFilesLocked() {
        let s = spec(.feature)
        #expect(s.stage == .discovery)
        #expect(s.docs == [.requirements: .locked, .architecture: .locked, .tasks: .locked])
    }

    @Test(arguments: SpecSize.allCases)
    func discoveryStartsTheSizesFirstFile(_ size: SpecSize) {
        var s = spec(size)
        do { let applied = s.apply(.discoveryFinished); #expect(applied) }
        #expect(s.stage == .drafting(size.files[0]))
        #expect(s.docs[size.files[0]] == .writing)
    }

    @Test func draftFinishedGoesToReview() {
        let s = inReview(.product)
        #expect(s.stage == .review(.product))
        #expect(s.docs[.product] == .review)
    }

    @Test func stopResumeAndFinishByHand() {
        var s = spec()
        s.apply(.discoveryFinished)
        s.apply(.draftStopped(.usageLimit(resetsAt: nil)))
        #expect(s.stage == .stopped(.product, .usageLimit(resetsAt: nil)))
        #expect(s.docs[.product] == .stopped)
        s.apply(.resume)
        #expect(s.stage == .drafting(.product))
        s.apply(.draftStopped(.user))
        s.apply(.finishByHand)
        #expect(s.stage == .review(.product))
    }

    @Test func approveWorksWithOpenItemsAndDraftsTheNextFile() {
        var s = inReview(.requirements, .feature)
        do { let applied = s.apply(.approve(.requirements)); #expect(applied) }
        #expect(s.docs[.requirements] == .approved)
        #expect(s.stage == .drafting(.architecture))
    }

    @Test func approvingTheLastFileStartsAnalyze() {
        var s = inReview(.tasks)
        s.apply(.approve(.tasks))
        #expect(s.stage == .analyze)
        #expect(s.analyze == .running)
        #expect(allApproved(s))
    }

    @Test func quickFixHasNoAnalyze() {
        var s = inReview(.spec, .quickFix)
        s.apply(.approve(.spec))
        #expect(s.stage == .done)
        #expect(s.analyze == .locked)
    }

    @Test func approveNeedsReview() {
        var s = spec()
        do { let applied = s.apply(.approve(.product)); #expect(!applied) }
        #expect(s == spec().with(id: s.id))
    }

    @Test func analyzeResultSetsStatusAndHandOffFinishes() {
        var s = analyzed(2)
        #expect(s.analyze == .issues(2))
        #expect(s.analysis?.issues.count == 2)
        #expect(s.stage == .analyze)
        do { let applied = s.apply(.analyzeFinished(result(0))); #expect(!applied) }   // only while running
        s.apply(.handOff)
        #expect(s.stage == .done)
        #expect(analyzed(0).analyze == .passed)
    }

    @Test func analyzeFailureShowsRerun() {
        var s = inReview(.tasks)
        s.apply(.approve(.tasks))
        s.apply(.analyzeFailed)
        #expect(s.analyze == .stale)
        s.apply(.rerunAnalyze)
        #expect(s.analyze == .running)
    }

    @Test func fixReviseRunsFilesInOrderThenAnalyzeAgain() {
        var s = analyzed(2)
        do { let applied = s.apply(.revise([.requirements, .tasks])); #expect(applied) }
        #expect(s.stage == .drafting(.requirements))
        #expect(s.queue == [.tasks])
        s.apply(.draftFinished)
        s.apply(.approve(.requirements))
        #expect(s.stage == .drafting(.tasks))
        #expect(s.queue.isEmpty)
        s.apply(.draftFinished)
        s.apply(.approve(.tasks))
        #expect(s.stage == .analyze)
        #expect(s.analyze == .running)
    }

    @Test func roundTwoAnswerRevisesTheFileInReview() {
        var s = inReview(.requirements)
        s.apply(.revise([.requirements]))
        #expect(s.stage == .drafting(.requirements))
        s.apply(.draftFinished)
        #expect(s.stage == .review(.requirements))
    }

    @Test func reviseIsRefusedWhileRunningOrForLockedFiles() {
        var s = spec()
        s.apply(.discoveryFinished)
        do { let applied = s.apply(.revise([.product])); #expect(!applied) }
        var r = inReview(.requirements)
        do { let applied = r.apply(.revise([.tasks])); #expect(!applied) }
    }

    @Test func editingAnApprovedFileMarksLaterFilesStale() {
        var s = analyzed()
        do { let applied = s.apply(.edited(.requirements)); #expect(applied) }
        #expect(s.docs[.product] == .approved)
        #expect(s.docs[.requirements] == .edited)
        #expect(s.docs[.experience] == .stale)
        #expect(s.docs[.architecture] == .stale)
        #expect(s.docs[.tasks] == .stale)
        #expect(s.analyze == .stale)
        #expect(s.stage == .analyze)
    }

    @Test func editingBeforeAnalyzeLeavesItLocked() {
        var s = inReview(.experience)
        s.apply(.edited(.product))
        #expect(s.docs[.requirements] == .stale)
        #expect(s.docs[.experience] == .review)   // in review, not stale
        #expect(s.analyze == .locked)
    }

    @Test func undoRestoresApprovedAndTheAnalyzeResult() {
        var s = analyzed(1)
        s.apply(.edited(.requirements))
        do { let applied = s.apply(.undo(.requirements)); #expect(applied) }
        #expect(allApproved(s))
        #expect(s.analyze == .issues(1))
    }

    @Test func undoKeepsFilesStaleBehindAnotherEdit() {
        var s = analyzed()
        s.apply(.edited(.architecture))
        s.apply(.edited(.product))
        s.apply(.undo(.product))
        #expect(s.docs[.requirements] == .approved)
        #expect(s.docs[.experience] == .approved)
        #expect(s.docs[.architecture] == .edited)
        #expect(s.docs[.tasks] == .stale)
        #expect(s.analyze == .stale)
    }

    @Test func keepAsIsClearsStale() {
        var s = analyzed()
        s.apply(.edited(.requirements))
        do { let applied = s.apply(.keepAsIs); #expect(applied) }
        #expect(allApproved(s))
        #expect(s.analyze == .stale)   // content changed: Rerun
        do { let applied = s.apply(.keepAsIs); #expect(!applied) }
    }

    @Test func refineRevisesEveryStaleFileThenAnalyze() {
        var s = analyzed()
        s.apply(.edited(.architecture))
        do { let applied = s.apply(.refine); #expect(applied) }
        #expect(s.docs[.architecture] == .approved)
        #expect(s.stage == .drafting(.tasks))
        s.apply(.draftFinished)
        s.apply(.approve(.tasks))
        #expect(s.stage == .analyze)
        #expect(s.analyze == .running)
    }

    @Test func reviseMidPipelineReturnsToTheFileInReview() {
        var s = inReview(.experience)
        s.apply(.edited(.product))
        s.apply(.refine)
        #expect(s.stage == .drafting(.requirements))
        s.apply(.draftFinished)
        s.apply(.approve(.requirements))
        #expect(s.stage == .review(.experience))
    }
}

private extension Spec {
    func with(id: UUID) -> Spec {
        Spec(id: id, name: name, idea: idea, size: size, folder: folder)
    }
}
