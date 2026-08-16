import AppKit

/// Writes a clip to the pasteboard, restores focus to whatever app was frontmost
/// before the clipboard window opened, and — if Accessibility access has been
/// granted — synthesizes ⌘V so the paste lands immediately instead of just
/// sitting on the clipboard for the user to paste manually.
@MainActor
final class Paster {
    private let clipStore: ClipStore
    private let clipboardMonitor: ClipboardMonitor

    init(clipStore: ClipStore, clipboardMonitor: ClipboardMonitor) {
        self.clipStore = clipStore
        self.clipboardMonitor = clipboardMonitor
    }

    func paste(_ clip: Clip, formatted: Bool, into previousApp: NSRunningApplication?) {
        PasteboardWriter.write(clip, formatted: formatted)
        clipboardMonitor.ownWriteChangeCount = NSPasteboard.general.changeCount
        try? clipStore.touch(id: clip.id)

        guard let previousApp else { return }
        previousApp.activate()

        guard AccessibilityPermission.isGranted else {
            AccessibilityPermission.promptIfNeeded()
            return
        }

        // A short delay lets `previousApp` actually finish becoming key before the
        // synthetic keystroke arrives; sending it immediately can race the app switch.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.06) {
            Self.sendCommandV()
        }
    }

    private static func sendCommandV() {
        guard let source = CGEventSource(stateID: .hidSystemState) else { return }
        let vKeyCode: CGKeyCode = 0x09 // kVK_ANSI_V

        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: vKeyCode, keyDown: true)
        keyDown?.flags = .maskCommand
        keyDown?.post(tap: .cgSessionEventTap)

        // Posting keyDown and keyUp back-to-back with zero gap is instantaneous
        // in a way a real keypress never is. Some web-based rich text editors
        // (Jira's comment field, a ProseMirror-based editor) mishandle that —
        // giving it a realistic hold duration avoids the double-insert.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.03) {
            let keyUp = CGEvent(keyboardEventSource: source, virtualKey: vKeyCode, keyDown: false)
            keyUp?.flags = .maskCommand
            keyUp?.post(tap: .cgSessionEventTap)
        }
    }
}
