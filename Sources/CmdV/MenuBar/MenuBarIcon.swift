import AppKit

/// The CmdV mark: two overlapping clipboard/card outlines (a clipboard
/// history) with a bold V on the front card. Drawn as a black-on-clear
/// template image so AppKit re-tints it automatically for light/dark menu
/// bars and active/inactive state.
enum MenuBarIcon {
    static func make() -> NSImage {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size, flipped: false) { rect in
            draw(in: rect, tint: .black)
            return true
        }
        image.isTemplate = true
        return image
    }

    /// Shared by the menu bar template render and the full-color app icon
    /// generator (`Scripts/GenerateAppIcon.swift`) so both use identical
    /// geometry. Stroke-only by design: a template image can't distinguish
    /// two different fill colors, only alpha, so there's no filled shape to
    /// "knock out" a glyph from — everything here is line art plus a filled V.
    static func draw(in rect: NSRect, tint: NSColor) {
        let back = NSBezierPath(roundedRect: NSRect(x: 4.3, y: 3.3, width: 11, height: 11.5), xRadius: 2, yRadius: 2)
        back.lineWidth = 1.3
        tint.setStroke()
        back.stroke()

        let front = NSBezierPath(roundedRect: NSRect(x: 2.3, y: 1.3, width: 11, height: 11.5), xRadius: 2, yRadius: 2)
        front.lineWidth = 1.5
        tint.setStroke()
        front.stroke()

        let vFont = NSFont.systemFont(ofSize: 8.4, weight: .heavy)
        let vString = NSAttributedString(string: "V", attributes: [.font: vFont, .foregroundColor: tint])
        let vSize = vString.size()
        vString.draw(at: NSPoint(x: 7.8 - vSize.width / 2, y: 7.05 - vSize.height / 2))
    }
}
