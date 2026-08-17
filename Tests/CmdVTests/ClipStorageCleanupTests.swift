import Foundation
import GRDB
import Testing
@testable import CmdV

/// Files on disk outliving the rows that referenced them is the failure mode
/// these cover: such files are invisible in the history, unaffected by the
/// history limit, and not removed when a concealed clip expires — so content
/// the user believes is gone stays readable.
@Suite struct ClipStorageCleanupTests {
    private func makeStore() throws -> ClipStore {
        let dbQueue = try DatabaseQueue()
        try AppDatabase.migrator.migrate(dbQueue)
        return ClipStore(dbQueue: dbQueue)
    }

    /// A directory of this test's own. The sweep must never be pointed at the
    /// real storage from a test.
    private func makeScratchDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("cmdv-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func makeFile(in directory: URL, named name: String) throws -> String {
        let url = directory.appendingPathComponent(name)
        try Data("payload".utf8).write(to: url)
        return url.path
    }

    private func exists(_ path: String) -> Bool {
        FileManager.default.fileExists(atPath: path)
    }

    @Test func repeatCopyDiscardsTheFilesItAlreadyWrote() throws {
        let store = try makeStore()
        let directory = try makeScratchDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let firstPath = try makeFile(in: directory, named: "first.plist")
        try store.insert(
            ClipPayload(kind: .text, plainText: "hi", previewText: "hi",
                        payloadPath: firstPath, contentHash: "same"),
            historyLimit: 50
        )

        // Same content hash, so this capture is deduped into the existing row
        // and never becomes a clip of its own.
        let repeatPath = try makeFile(in: directory, named: "repeat.plist")
        try store.insert(
            ClipPayload(kind: .text, plainText: "hi", previewText: "hi",
                        payloadPath: repeatPath, contentHash: "same"),
            historyLimit: 50
        )

        #expect(!exists(repeatPath), "the deduped capture's file must not survive")
        #expect(exists(firstPath), "the stored clip's own file must be left alone")
    }

    @Test func repeatCopyDiscardsImageAndThumbnailToo() throws {
        let store = try makeStore()
        let directory = try makeScratchDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        try store.insert(
            ClipPayload(kind: .image, previewText: "Image", contentHash: "same"),
            historyLimit: 50
        )

        let image = try makeFile(in: directory, named: "repeat.png")
        let thumb = try makeFile(in: directory, named: "repeat_thumb.png")
        try store.insert(
            ClipPayload(kind: .image, previewText: "Image", imagePath: image,
                        thumbPath: thumb, contentHash: "same"),
            historyLimit: 50
        )

        #expect(!exists(image))
        #expect(!exists(thumb))
    }

    @Test func sweepRemovesUnreferencedFilesAndKeepsTheRest() throws {
        let store = try makeStore()
        let directory = try makeScratchDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let referenced = try makeFile(in: directory, named: "referenced.plist")
        try store.insert(
            ClipPayload(kind: .text, plainText: "kept", previewText: "kept",
                        payloadPath: referenced, contentHash: "kept"),
            historyLimit: 50
        )
        let orphanA = try makeFile(in: directory, named: "orphan-a.plist")
        let orphanB = try makeFile(in: directory, named: "orphan-b.png")

        let removed = try store.sweepOrphanedFiles(in: [directory])

        #expect(removed == 2)
        #expect(!exists(orphanA))
        #expect(!exists(orphanB))
        #expect(exists(referenced), "a file a clip still points at must survive the sweep")
    }

    @Test func sweepKeepsImagesAndThumbnailsThatAreStillReferenced() throws {
        let store = try makeStore()
        let directory = try makeScratchDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let image = try makeFile(in: directory, named: "kept.png")
        let thumb = try makeFile(in: directory, named: "kept_thumb.png")
        try store.insert(
            ClipPayload(kind: .image, previewText: "Image", imagePath: image,
                        thumbPath: thumb, contentHash: "image"),
            historyLimit: 50
        )

        #expect(try store.sweepOrphanedFiles(in: [directory]) == 0)
        #expect(exists(image))
        #expect(exists(thumb), "thumbnails are referenced too, not just the full image")
    }

    /// The paths a clip stores and the paths `contentsOfDirectory` reports are
    /// not textually equal when any parent is a symlink — macOS resolves
    /// `/var` to `/private/var` on the way out. Comparing them raw made every
    /// referenced file look like an orphan, so the sweep deleted live clip data.
    @Test func sweepMatchesPathsThroughSymlinkedParents() throws {
        let store = try makeStore()
        let directory = try makeScratchDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let stored = try makeFile(in: directory, named: "referenced.plist")
        let listed = try #require(
            FileManager.default
                .contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
                .first?.path
        )
        try #require(stored != listed, "this test is meaningless unless the two forms differ textually")

        try store.insert(
            ClipPayload(kind: .text, plainText: "k", previewText: "k",
                        payloadPath: stored, contentHash: "k"),
            historyLimit: 50
        )

        #expect(try store.sweepOrphanedFiles(in: [directory]) == 0)
        #expect(exists(stored))
    }

    @Test func sweepOfAnAlreadyCleanDirectoryRemovesNothing() throws {
        let store = try makeStore()
        let directory = try makeScratchDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        #expect(try store.sweepOrphanedFiles(in: [directory]) == 0)
    }

    /// Deleting a clip already removed its files; the sweep must not then be
    /// what notices, or a bug in `delete` would go unseen.
    @Test func deletingAClipRemovesItsFilesWithoutTheSweep() throws {
        let store = try makeStore()
        let directory = try makeScratchDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let path = try makeFile(in: directory, named: "doomed.plist")
        let clip = try store.insert(
            ClipPayload(kind: .text, plainText: "bye", previewText: "bye",
                        payloadPath: path, contentHash: "bye"),
            historyLimit: 50
        )

        try store.delete(id: clip.id)

        #expect(!exists(path))
    }
}
