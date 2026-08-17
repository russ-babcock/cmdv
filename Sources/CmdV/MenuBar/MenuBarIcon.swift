import AppKit

/// The CmdV mark as it appears in the menu bar.
///
/// Loaded from bundled art rather than drawn in code: the artwork is the design
/// source of truth (see `CmdV-3A-Paper/`), and hinting a shape this small by
/// hand in Core Graphics is a losing game.
enum MenuBarIcon {
    /// Menu bar items are laid out in points; 18pt is the standard mark size.
    private static let pointSize = NSSize(width: 18, height: 18)

    static func make() -> NSImage {
        let image = load() ?? NSImage(size: pointSize)
        image.size = pointSize
        // Template rendering is what makes the mark invert for a light or dark
        // menu bar and tint when the item is highlighted. Without it the icon
        // stays black and disappears against a dark menu bar.
        image.isTemplate = true
        return image
    }

    /// The 1x/2x/3x PNGs become representations of a single image, so AppKit
    /// picks the right one per display rather than scaling one master.
    private static func load() -> NSImage? {
        let scales = ["CmdVmenubarTemplate", "CmdVmenubarTemplate@2x", "CmdVmenubarTemplate@3x"]
        let representations = scales.compactMap { name -> NSImageRep? in
            guard let url = Bundle.module.url(forResource: name, withExtension: "png"),
                  let data = try? Data(contentsOf: url)
            else { return nil }
            return NSBitmapImageRep(data: data)
        }
        guard !representations.isEmpty else {
            NSLog("CmdV: menu bar icon art missing from bundle")
            return nil
        }

        let image = NSImage(size: pointSize)
        representations.forEach(image.addRepresentation)
        return image
    }
}
