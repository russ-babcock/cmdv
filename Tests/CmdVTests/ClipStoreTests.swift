import Foundation
import GRDB
import Testing
@testable import CmdV

@Suite struct ClipStoreTests {
    private func makeStore() throws -> ClipStore {
        let dbQueue = try DatabaseQueue()
        try AppDatabase.migrator.migrate(dbQueue)
        return ClipStore(dbQueue: dbQueue)
    }

    private func payload(_ text: String, expiresAt: Date? = nil) -> ClipPayload {
        ClipPayload(
            kind: .text,
            plainText: text,
            previewText: text,
            isConcealed: expiresAt != nil,
            expiresAt: expiresAt,
            contentHash: text
        )
    }

    @Test func consecutiveDuplicateBumpsInsteadOfInserting() throws {
        let store = try makeStore()

        try store.insert(payload("hello"), historyLimit: 50)
        try store.insert(payload("hello"), historyLimit: 50)
        try store.insert(payload("hello"), historyLimit: 50)

        let all = try store.fetchAll()
        #expect(all.count == 1)
        #expect(all[0].useCount == 2)
    }

    @Test func nonConsecutiveDuplicateInsertsSeparateRow() throws {
        let store = try makeStore()

        try store.insert(payload("a"), historyLimit: 50)
        try store.insert(payload("b"), historyLimit: 50)
        try store.insert(payload("a"), historyLimit: 50)

        let all = try store.fetchAll()
        #expect(all.count == 3)
    }

    @Test func evictionTrimsOldestUnpinnedUnfavoritedRows() throws {
        let store = try makeStore()

        for i in 0..<10 {
            try store.insert(payload("clip-\(i)"), historyLimit: 5)
        }

        let all = try store.fetchAll()
        #expect(all.count == 5)

        let texts = Set(all.compactMap(\.plainText))
        #expect(texts == ["clip-5", "clip-6", "clip-7", "clip-8", "clip-9"])
    }

    @Test func favoritesAndPinsSurviveEviction() throws {
        let store = try makeStore()

        let favoriteClip = try store.insert(payload("keep-favorite"), historyLimit: 3)
        try store.setFavorite(id: favoriteClip.id, true)

        let pinnedClip = try store.insert(payload("keep-pinned"), historyLimit: 3)
        try store.setPin(id: pinnedClip.id, key: "1")

        for i in 0..<10 {
            try store.insert(payload("filler-\(i)"), historyLimit: 3)
        }

        let all = try store.fetchAll()
        let ids = Set(all.map(\.id))
        #expect(ids.contains(favoriteClip.id))
        #expect(ids.contains(pinnedClip.id))

        let evictableCount = all.filter { $0.pinKey == nil && !$0.isFavorite }.count
        #expect(evictableCount == 3)
    }

    @Test func pinAssignmentStealsKeyFromPreviousHolder() throws {
        let store = try makeStore()

        let first = try store.insert(payload("first"), historyLimit: 50)
        let second = try store.insert(payload("second"), historyLimit: 50)

        try store.setPin(id: first.id, key: "5")
        try store.setPin(id: second.id, key: "5")

        let refreshedFirst = try store.fetch(id: first.id)
        let refreshedSecond = try store.fetch(id: second.id)
        #expect(refreshedFirst?.pinKey == nil)
        #expect(refreshedSecond?.pinKey == "5")
    }

    @Test func purgeExpiredRemovesOnlyPastDeadlines() throws {
        let store = try makeStore()

        let expired = try store.insert(payload("password", expiresAt: Date().addingTimeInterval(-5)), historyLimit: 50)
        let notYetExpired = try store.insert(payload("still-fresh", expiresAt: Date().addingTimeInterval(60)), historyLimit: 50)
        let ordinary = try store.insert(payload("ordinary"), historyLimit: 50)

        let didRemoveSomething = try store.purgeExpired()

        #expect(didRemoveSomething)
        let remainingIDs = Set(try store.fetchAll().map(\.id))
        #expect(!remainingIDs.contains(expired.id))
        #expect(remainingIDs.contains(notYetExpired.id))
        #expect(remainingIDs.contains(ordinary.id))
    }

    @Test func purgeExpiredReportsFalseWhenNothingToRemove() throws {
        let store = try makeStore()
        try store.insert(payload("ordinary"), historyLimit: 50)

        let didRemoveSomething = try store.purgeExpired()

        #expect(!didRemoveSomething)
    }
}
