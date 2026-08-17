import AppKit
import Foundation
import Testing
@testable import CmdV

@MainActor
@Suite struct PasteboardWriterTests {
    private let richType = NSPasteboard.PasteboardType("public.rtf")

    private func makeClipWithRichPayload() throws -> Clip {
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(UUID().uuidString).plist")
        let representations: [String: Data] = [richType.rawValue: Data("{\\rtf1 hello}".utf8)]
        let plistData = try PropertyListSerialization.data(fromPropertyList: representations, format: .binary, options: 0)
        try plistData.write(to: tempURL)

        return Clip(
            kind: .text,
            plainText: "hello",
            previewText: "hello",
            payloadPath: tempURL.path,
            contentHash: "hello"
        )
    }

    @Test func plainPasteWritesOnlyStringType() throws {
        let clip = try makeClipWithRichPayload()
        PasteboardWriter.write(clip, formatted: false)

        let pasteboard = NSPasteboard.general
        #expect(pasteboard.string(forType: .string) == "hello")
        #expect(pasteboard.data(forType: richType) == nil)
    }

    @Test func formattedPasteWritesRichTypeAlongsidePlainText() throws {
        let clip = try makeClipWithRichPayload()
        PasteboardWriter.write(clip, formatted: true)

        let pasteboard = NSPasteboard.general
        #expect(pasteboard.string(forType: .string) == "hello")
        #expect(pasteboard.data(forType: richType) != nil)
    }

    /// Pasting a copied file has to put real file references back on the
    /// pasteboard, not the text of their paths — that difference is what makes
    /// a paste into Finder copy the files rather than type their names.
    @Test func fileClipWritesRealFileURLs() throws {
        let directory = FileManager.default.temporaryDirectory
        let first = directory.appendingPathComponent("\(UUID().uuidString) spaced.txt")
        let second = directory.appendingPathComponent("\(UUID().uuidString).md")
        try Data("one".utf8).write(to: first)
        try Data("two".utf8).write(to: second)
        defer {
            try? FileManager.default.removeItem(at: first)
            try? FileManager.default.removeItem(at: second)
        }

        let clip = Clip(
            kind: .fileURL,
            plainText: [first, second].map(\.absoluteString).joined(separator: "\n"),
            previewText: ClipboardMonitor.fileClipPreview(for: [first, second]),
            contentHash: "files"
        )
        PasteboardWriter.write(clip, formatted: false)

        let written = NSPasteboard.general.readObjects(forClasses: [NSURL.self], options: nil) as? [URL]
        let paths = try #require(written).map(\.path)
        #expect(paths == [first.path, second.path])
        // A name with a space survives the percent-encoding round trip.
        #expect(paths.allSatisfy { FileManager.default.fileExists(atPath: $0) })
    }
}
