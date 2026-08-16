import AppKit
import Carbon.HIToolbox
import SwiftUI

/// A click-to-record control: click it, then press a key combo (at least one
/// modifier required) to capture a new `KeyCombo`. Esc cancels recording.
struct HotkeyRecorder: NSViewRepresentable {
    let combo: KeyCombo
    let onCapture: (KeyCombo) -> Void

    func makeNSView(context: Context) -> RecorderView {
        let view = RecorderView()
        view.onCapture = onCapture
        view.combo = combo
        return view
    }

    func updateNSView(_ nsView: RecorderView, context: Context) {
        nsView.combo = combo
    }

    final class RecorderView: NSView {
        var combo: KeyCombo = .default {
            didSet { needsDisplay = true }
        }
        var onCapture: ((KeyCombo) -> Void)?
        private var isRecording = false {
            didSet { needsDisplay = true }
        }

        override var acceptsFirstResponder: Bool { true }
        override var intrinsicContentSize: NSSize { NSSize(width: 160, height: 24) }

        override func mouseDown(with event: NSEvent) {
            window?.makeFirstResponder(self)
            isRecording = true
        }

        override func keyDown(with event: NSEvent) {
            guard isRecording else {
                super.keyDown(with: event)
                return
            }
            if event.keyCode == UInt16(kVK_Escape) {
                isRecording = false
                return
            }
            let modifiers = Self.carbonModifiers(from: event.modifierFlags)
            guard modifiers != 0 else { return } // require at least one modifier
            let newCombo = KeyCombo(keyCode: UInt32(event.keyCode), carbonModifiers: modifiers)
            combo = newCombo
            isRecording = false
            onCapture?(newCombo)
        }

        override func draw(_ dirtyRect: NSRect) {
            let path = NSBezierPath(roundedRect: bounds.insetBy(dx: 1, dy: 1), xRadius: 6, yRadius: 6)
            (isRecording ? NSColor.controlAccentColor.withAlphaComponent(0.15) : NSColor.controlBackgroundColor).setFill()
            path.fill()
            (isRecording ? NSColor.controlAccentColor : NSColor.separatorColor).setStroke()
            path.lineWidth = 1
            path.stroke()

            let text = isRecording ? "Press keys\u{2026}" : combo.displayString
            let attributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 12, weight: .medium),
                .foregroundColor: isRecording ? NSColor.controlAccentColor : NSColor.labelColor
            ]
            let size = text.size(withAttributes: attributes)
            let origin = NSPoint(x: (bounds.width - size.width) / 2, y: (bounds.height - size.height) / 2)
            text.draw(at: origin, withAttributes: attributes)
        }

        static func carbonModifiers(from flags: NSEvent.ModifierFlags) -> UInt32 {
            var result: UInt32 = 0
            if flags.contains(.command) { result |= UInt32(cmdKey) }
            if flags.contains(.option) { result |= UInt32(optionKey) }
            if flags.contains(.control) { result |= UInt32(controlKey) }
            if flags.contains(.shift) { result |= UInt32(shiftKey) }
            return result
        }
    }
}
