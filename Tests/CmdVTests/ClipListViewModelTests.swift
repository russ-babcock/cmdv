import Foundation
import GRDB
import Testing
@testable import CmdV

@MainActor
@Suite struct ClipListViewModelTests {
    private func makeModel() throws -> ClipListViewModel {
        let dbQueue = try DatabaseQueue()
        try AppDatabase.migrator.migrate(dbQueue)
        return ClipListViewModel(clipStore: ClipStore(dbQueue: dbQueue))
    }

    private func clip(_ id: String, pinKey: String? = nil, createdAt: Date = Date()) -> Clip {
        Clip(id: id, createdAt: createdAt, kind: .text, previewText: id, pinKey: pinKey, contentHash: id)
    }

    @Test func unpinnedClipsAreNumberedByPosition() throws {
        let model = try makeModel()
        model.clips = [clip("a"), clip("b"), clip("c")]

        let keys = model.effectivePinKeys
        #expect(keys["a"] == "1")
        #expect(keys["b"] == "2")
        #expect(keys["c"] == "3")
    }

    @Test func lockedClipReservesItsKeyAndOthersSkipOverIt() throws {
        let model = try makeModel()
        model.clips = [clip("a"), clip("b", pinKey: "1"), clip("c")]

        let keys = model.effectivePinKeys
        #expect(keys["b"] == "1")
        #expect(keys["a"] == "2")
        #expect(keys["c"] == "3")
    }

    @Test func lockedClipKeepsItsKeyRegardlessOfPosition() throws {
        let model = try makeModel()
        model.clips = [clip("a", pinKey: "5"), clip("b"), clip("c")]

        let keys = model.effectivePinKeys
        #expect(keys["a"] == "5")
        #expect(keys["b"] == "1")
        #expect(keys["c"] == "2")
    }

    @Test func clipAtEffectiveKeyFindsAutoNumberedClip() throws {
        let model = try makeModel()
        model.clips = [clip("a"), clip("b"), clip("c")]

        #expect(model.clip(atEffectiveKey: "2")?.id == "b")
        #expect(model.clip(atEffectiveKey: "9") == nil)
    }

    @Test func clipAtEffectiveKeyFindsLockedClip() throws {
        let model = try makeModel()
        model.clips = [clip("a"), clip("b", pinKey: "7"), clip("c")]

        #expect(model.clip(atEffectiveKey: "7")?.id == "b")
    }
}
