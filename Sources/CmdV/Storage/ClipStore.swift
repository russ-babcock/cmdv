import Foundation
import GRDB

/// Owns all reads and writes to the clip history. `ClipboardMonitor` is the only
/// caller of `insert`; UI code calls the rest.
final class ClipStore: @unchecked Sendable {
    private let dbQueue: DatabaseQueue

    init(dbQueue: DatabaseQueue) {
        self.dbQueue = dbQueue
    }

    // MARK: Reads

    func fetchAll() throws -> [Clip] {
        try dbQueue.read { db in
            try Clip
                .order(Column("createdAt").desc)
                .fetchAll(db)
        }
    }

    func fetch(id: String) throws -> Clip? {
        try dbQueue.read { db in try Clip.fetchOne(db, key: id) }
    }

    // MARK: Insert + dedup

    /// Inserts a new clip, or — if its content hash matches the single most recent
    /// clip — treats it as a repeat copy and bumps that row instead.
    @discardableResult
    func insert(_ payload: ClipPayload, historyLimit: Int) throws -> Clip {
        try dbQueue.write { db in
            if var newest = try Clip.order(Column("createdAt").desc).fetchOne(db),
               newest.contentHash == payload.contentHash {
                newest.lastUsedAt = Date()
                newest.useCount += 1
                try newest.update(db)
                return newest
            }

            var clip = payload.makeClip()
            try clip.insert(db)
            try Self.evictIfNeeded(db, limit: historyLimit)
            return clip
        }
    }

    // MARK: Mutations

    func setFavorite(id: String, _ isFavorite: Bool) throws {
        try dbQueue.write { db in
            try db.execute(
                sql: "UPDATE clip SET isFavorite = ? WHERE id = ?",
                arguments: [isFavorite, id]
            )
        }
    }

    /// Assigns `key` to the given clip, stealing it from whichever other clip
    /// currently holds it. Pass `nil` to unpin.
    func setPin(id: String, key: String?) throws {
        try dbQueue.write { db in
            if let key {
                try db.execute(
                    sql: "UPDATE clip SET pinKey = NULL WHERE pinKey = ? AND id != ?",
                    arguments: [key, id]
                )
            }
            try db.execute(
                sql: "UPDATE clip SET pinKey = ? WHERE id = ?",
                arguments: [key, id]
            )
        }
    }

    func delete(id: String) throws {
        guard let clip = try fetch(id: id) else { return }
        try dbQueue.write { db in
            _ = try Clip.deleteOne(db, key: id)
        }
        ImageStore.deleteFiles(for: clip)
    }

    func touch(id: String) throws {
        try dbQueue.write { db in
            try db.execute(
                sql: "UPDATE clip SET lastUsedAt = ?, useCount = useCount + 1 WHERE id = ?",
                arguments: [Date(), id]
            )
        }
    }

    // MARK: Privacy

    /// Deletes concealed clips whose `expiresAt` has passed. Called on a 5s
    /// timer by `ClipboardMonitor`, independent of pasteboard polling — a clip
    /// must expire even if nothing new is copied. Returns whether anything was
    /// actually removed, so callers can skip refreshing the UI when nothing changed.
    @discardableResult
    func purgeExpired() throws -> Bool {
        let now = Date()
        let expired = try dbQueue.read { db in
            try Clip
                .filter(Column("expiresAt") != nil && Column("expiresAt") <= now)
                .fetchAll(db)
        }
        guard !expired.isEmpty else { return false }

        try dbQueue.write { db in
            for clip in expired {
                _ = try Clip.deleteOne(db, key: clip.id)
            }
        }
        for clip in expired {
            ImageStore.deleteFiles(for: clip)
        }
        return true
    }

    // MARK: Eviction

    private static func evictIfNeeded(_ db: Database, limit: Int) throws {
        let evictable = Column("pinKey") == nil && Column("isFavorite") == false
        let count = try Clip.filter(evictable).fetchCount(db)
        guard count > limit else { return }

        let overflow = try Clip
            .filter(evictable)
            .order(Column("createdAt").asc)
            .limit(count - limit)
            .fetchAll(db)

        for clip in overflow {
            _ = try Clip.deleteOne(db, key: clip.id)
            ImageStore.deleteFiles(for: clip)
        }
    }
}
