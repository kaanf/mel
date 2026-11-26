import Testing
@testable import MelSpec

struct PatchTests {
    private let file = "# Tasks\n\n- [ ] 1. Booking store\n  - Covers: 1.1\n- [ ] 2. Class packs\n  - Covers: 2.1\n"

    private func patch(_ edits: (String, String)...) -> Patch {
        Patch(edits: edits.map { Patch.Edit(old: $0.0, new: $0.1) })
    }

    @Test func replacesAddsAndRemoves() {
        let edited = patch(("Booking store", "Booking store, two spots"),
                           ("  - Covers: 2.1\n", "  - Covers: 2.1\n- [ ] 3. Waitlist\n"),
                           ("  - Covers: 1.1\n", "")).apply(to: file)
        #expect(edited == "# Tasks\n\n- [ ] 1. Booking store, two spots\n- [ ] 2. Class packs\n  - Covers: 2.1\n- [ ] 3. Waitlist\n")
    }

    @Test func noEditsKeepTheFile() {
        #expect(patch().apply(to: file) == file)
    }

    @Test func laterEditsSeeEarlierOnes() {
        #expect(patch(("1.1", "1.2"), ("Covers: 1.2", "Covers: 1.3")).apply(to: file)?.contains("Covers: 1.3") == true)
    }

    @Test(arguments: ["Waitlist", "  - Covers: ", "booking store", "- [ ] 1.  Booking", ""])
    func oldMissingRepeatedOrInexactIsUnplaced(_ old: String) {
        #expect(patch((old, "x")).apply(to: file) == nil)
    }

    @Test func overlappingRepeatIsUnplaced() {
        #expect(patch(("aa", "b")).apply(to: "aaa") == nil)
    }

    @Test func oneUnplacedEditAppliesNothing() {
        #expect(patch(("Booking store", "Store"), ("Waitlist", "x")).apply(to: file) == nil)
    }

    @Test func decodesTheReply() throws {
        let reply = "```json\n{\"edits\": [{\"old\": \"a\\nb\", \"new\": \"\"}]}\n```"
        #expect(try Patch.decode(reply) == patch(("a\nb", "")))
        #expect(throws: (any Error).self) { try Patch.decode("I changed story 2.") }
        #expect(throws: (any Error).self) { try Patch.decode(#"{"edits": [{"old": "a"}]}"#) }
    }
}
