import Testing
@testable import MelSpec

struct ConversationTests {
    @Test func onlyFilesChangedSinceTheConversationSawThemAreSentAgain() {
        var conversation = Conversation(id: "s1")
        var documents: [DocKind: String] = [.requirements: "# Requirements\n", .tasks: "# Tasks\n"]
        #expect(conversation.unseen([.requirements, .tasks], in: documents) == [.requirements, .tasks])

        conversation.saw(documents)
        #expect(conversation.unseen([.requirements, .tasks], in: documents).isEmpty)

        documents[.tasks] = "# Tasks\n\n- [ ] 1. Store\n"   // an edit by hand, an Undo or a scope move
        #expect(conversation.unseen([.requirements, .tasks], in: documents) == [.tasks])

        conversation.forget([.requirements])   // edits it sent that weren't placed
        #expect(conversation.unseen([.requirements, .tasks], in: documents) == [.requirements, .tasks])
    }

    @Test func fingerprintsAreStable() {
        #expect(Conversation.fingerprint("") == 14_695_981_039_346_656_037)
        #expect(Conversation.fingerprint("a") == 12_638_187_200_555_641_996)
    }
}
