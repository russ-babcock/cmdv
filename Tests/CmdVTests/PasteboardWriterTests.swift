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
}
