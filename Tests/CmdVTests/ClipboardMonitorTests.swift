import Foundation
import Testing
@testable import CmdV

@MainActor
@Suite struct ClipboardMonitorTests {
    @Test func singleFileShowsItsName() {
        let preview = ClipboardMonitor.fileClipPreview(for: [URL(fileURLWithPath: "/tmp/report.pdf")])
        #expect(preview == "report.pdf")
    }

    @Test func twoFilesCountTheRemainderInTheSingular() {
        let preview = ClipboardMonitor.fileClipPreview(for: [
            URL(fileURLWithPath: "/tmp/report.pdf"),
            URL(fileURLWithPath: "/tmp/notes.md")
        ])
        #expect(preview == "report.pdf + 1 more")
    }

    @Test func manyFilesCountTheRemainder() {
        let preview = ClipboardMonitor.fileClipPreview(for: [
            URL(fileURLWithPath: "/tmp/a.png"),
            URL(fileURLWithPath: "/tmp/b.png"),
            URL(fileURLWithPath: "/tmp/c.png")
        ])
        #expect(preview == "a.png + 2 more")
    }

    /// Clips store the percent-encoded absolute URL, because that is what
    /// round-trips back onto the pasteboard — but a row has to show the name a
    /// person recognises, not `My%20File.png`.
    @Test func percentEncodedNamesAreShownDecoded() throws {
        let url = try #require(URL(string: "file:///tmp/Camo%20Logos%20-%20Final.png"))
        #expect(ClipboardMonitor.fileClipPreview(for: [url]) == "Camo Logos - Final.png")
    }

    @Test func noFilesProducesEmptyPreview() {
        #expect(ClipboardMonitor.fileClipPreview(for: []).isEmpty)
    }

    /// A folder's URL carries a trailing slash; the name still has to come out.
    @Test func directoryNameSurvivesTrailingSlash() throws {
        let url = try #require(URL(string: "file:///Applications/CmdV.app/"))
        #expect(ClipboardMonitor.fileClipPreview(for: [url]) == "CmdV.app")
    }
}
