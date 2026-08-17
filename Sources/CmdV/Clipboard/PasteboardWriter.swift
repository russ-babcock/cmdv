import AppKit

enum PasteboardWriter {
    /// Writes `clip` to a pasteboard, the general one unless told otherwise.
    /// `formatted` controls whether the full stored representation set
    /// (RTF/HTML/etc.) is restored alongside the plain text, or just the plain
    /// text alone — the mechanism behind "paste as plain text" (default) vs.
    /// "Paste with Formatting" (right-click).
    ///
    /// The pasteboard is a parameter purely so tests can hand over a private
    /// one: writing to `.general` in a test replaces whatever the person
    /// running it had on their clipboard, and CmdV, watching the pasteboard,
    /// dutifully records the test fixtures as real clips.
    static func write(_ clip: Clip, formatted: Bool, to pasteboard: NSPasteboard = .general) {
        pasteboard.clearContents()

        switch clip.kind {
        case .image:
            guard let imagePath = clip.imagePath,
                  let data = FileManager.default.contents(atPath: imagePath) else { return }
            pasteboard.setData(data, forType: .png)

        case .fileURL:
            guard let plainText = clip.plainText else { return }
            let urls = plainText.split(separator: "\n").compactMap { URL(string: String($0)) as NSURL? }
            pasteboard.writeObjects(urls as [NSPasteboardWriting])

        case .text, .rtf, .html:
            if formatted, let payloadPath = clip.payloadPath,
               let representations = ImageStore.loadPayload(at: payloadPath) {
                for (typeRaw, data) in representations {
                    pasteboard.setData(data, forType: NSPasteboard.PasteboardType(typeRaw))
                }
            }
            if let plainText = clip.plainText {
                pasteboard.setString(plainText, forType: .string)
            }
        }
    }
}
