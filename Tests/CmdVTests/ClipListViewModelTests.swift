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

    // MARK: Sidebar filters

    private func clip(_ id: String, kind: ClipKind) -> Clip {
        Clip(id: id, kind: kind, previewText: id, contentHash: id)
    }

    private func mixedClips() -> [Clip] {
        [clip("text", kind: .text), clip("file", kind: .fileURL), clip("image", kind: .image)]
    }

    @Test func filesFilterShowsOnlyCopiedFiles() throws {
        let model = try makeModel()
        model.clips = mixedClips()
        model.sidebarFilter = .files

        #expect(model.filteredClips.map(\.id) == ["file"])
    }

    /// Copied files used to be lumped in with Text because there was nowhere
    /// else for them; now that Files exists they must not appear in both.
    @Test func textFilterNoLongerIncludesCopiedFiles() throws {
        let model = try makeModel()
        model.clips = mixedClips()
        model.sidebarFilter = .text

        #expect(model.filteredClips.map(\.id) == ["text"])
    }

    @Test func imagesFilterIsUnaffected() throws {
        let model = try makeModel()
        model.clips = mixedClips()
        model.sidebarFilter = .images

        #expect(model.filteredClips.map(\.id) == ["image"])
    }

    @Test func everyClipKindIsReachableFromSomeFilter() throws {
        let model = try makeModel()
        model.clips = ClipKind.allCases.map { clip($0.rawValue, kind: $0) }

        var seen: Set<String> = []
        for filter in SidebarFilter.allCases where filter != .all {
            model.sidebarFilter = filter
            seen.formUnion(model.filteredClips.map(\.id))
        }

        // Favorites and Pinned match nothing here, so this is really asking
        // that no clip kind is invisible under every content filter.
        #expect(seen == Set(ClipKind.allCases.map(\.rawValue)))
    }
}
