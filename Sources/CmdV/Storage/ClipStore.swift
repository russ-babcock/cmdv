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
                // This capture is never stored, but the monitor already wrote
                // its image and payload files. Without this they would sit on
                // disk forever: invisible in the UI, untouched by the history
                // limit, and not purged when a concealed clip expires.
                ImageStore.deleteFiles(for: payload)
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

    /// Replaces a text clip's content with `newText`.
    ///
    /// Any stored rich representations are dropped. They were captured
    /// alongside the original text and describe it, so after an edit "Paste
    /// with Formatting" would paste the *old* wording — an edit that silently
    /// doesn't apply is worse than losing the formatting. The payload file goes
    /// with them rather than being left behind as an orphan.
    ///
    /// `lastUsedAt` is deliberately untouched: editing a clip is not using it,
    /// and bumping it would shuffle the row out from under the person editing.
    func updateText(id: String, to newText: String) throws {
        guard let clip = try fetch(id: id) else { return }
        let stalePayloadPath = clip.payloadPath

        try dbQueue.write { db in
            var updated = clip
            updated.plainText = newText
            updated.previewText = String(newText.prefix(500))
            updated.contentHash = ContentHash.of(newText)
            updated.payloadPath = nil
            try updated.update(db)
        }

        if let stalePayloadPath {
            ImageStore.deletePayload(at: stalePayloadPath)
        }
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

    // MARK: Orphan sweep

    /// Deletes stored files that no clip refers to, returning how many went.
    ///
    /// Orphans are content the user believes is gone: they don't appear in the
    /// history, survive the history limit, and outlive the 60-second purge that
    /// concealed clips rely on. Earlier builds produced them on every repeat
    /// copy, so this also cleans up after them.
    ///
    /// The directories are a parameter so tests operate on their own temporary
    /// ones — a sweep pointed at the real storage would be destructive to run
    /// under test.
    @discardableResult
    func sweepOrphanedFiles(
        in directories: [URL] = [AppPaths.imagesDirectory, AppPaths.payloadsDirectory]
    ) throws -> Int {
        let referenced = try dbQueue.read { db -> Set<String> in
            var paths: Set<String> = []
            for clip in try Clip.fetchAll(db) {
                for path in [clip.imagePath, clip.thumbPath, clip.payloadPath] {
                    if let path { paths.insert(Self.canonicalPath(path)) }
                }
            }
            return paths
        }

        let fm = FileManager.default
        var removed = 0
        for directory in directories {
            let contents = (try? fm.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: nil
            )) ?? []
            for url in contents where !referenced.contains(Self.canonicalPath(url.path)) {
                do {
                    try fm.removeItem(at: url)
                    removed += 1
                } catch {
                    NSLog("CmdV: could not remove orphaned file \(url.lastPathComponent): \(error)")
                }
            }
        }
        return removed
    }

    /// Both sides of the referenced/on-disk comparison have to be reduced to the
    /// same form before matching, or the sweep deletes files that are in use.
    /// `contentsOfDirectory` hands back symlink-resolved paths (`/private/var/…`)
    /// while a stored path is whatever was recorded at write time (`/var/…`), and
    /// on macOS those name the same file.
    private static func canonicalPath(_ path: String) -> String {
        URL(fileURLWithPath: path).resolvingSymlinksInPath().standardizedFileURL.path
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
