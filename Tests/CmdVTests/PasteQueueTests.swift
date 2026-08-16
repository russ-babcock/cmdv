import Testing
@testable import CmdV

@MainActor
@Suite struct PasteQueueTests {
    @Test func recordsIncrementingOrder() {
        let queue = PasteQueue()
        queue.activate()

        queue.recordPaste("a")
        queue.recordPaste("b")
        queue.recordPaste("c")

        #expect(queue.order(for: "a") == 1)
        #expect(queue.order(for: "b") == 2)
        #expect(queue.order(for: "c") == 3)
        #expect(queue.pastedCount == 3)
    }

    @Test func rePastingAlreadyPastedClipMovesItToLatestPosition() {
        let queue = PasteQueue()
        queue.activate()

        queue.recordPaste("a")
        queue.recordPaste("b")
        queue.recordPaste("a")

        #expect(queue.order(for: "a") == 3)
        #expect(queue.order(for: "b") == 2)
        #expect(queue.pastedCount == 2)
    }

    @Test func deactivateClearsAllBadges() {
        let queue = PasteQueue()
        queue.activate()
        queue.recordPaste("a")

        queue.deactivate()

        #expect(!queue.isActive)
        #expect(queue.order(for: "a") == nil)
        #expect(queue.pastedCount == 0)
    }

    @Test func toggleFlipsActiveStateAndResetsOnDeactivate() {
        let queue = PasteQueue()

        queue.toggle()
        #expect(queue.isActive)

        queue.recordPaste("a")
        queue.toggle()
        #expect(!queue.isActive)
        #expect(queue.pastedCount == 0)
    }
}
