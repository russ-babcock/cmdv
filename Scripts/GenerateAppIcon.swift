// Renders the CmdV mark (two overlapping card outlines + bold V) as a
// full-color app icon at every pixel size macOS needs, scaled up from the
// same geometry as the menu bar template in Sources/CmdV/MenuBar/MenuBarIcon.swift.
import AppKit

func renderIcon(pixelSize: Int, to path: String) {
    let canvas = CGFloat(pixelSize)
    let s = canvas / 18.0 // same 18x18 unit canvas as the menu bar icon

    let image = NSImage(size: NSSize(width: canvas, height: canvas))
    image.lockFocus()
    NSGraphicsContext.current?.imageInterpolation = .high

    let bgPath = NSBezierPath(
        roundedRect: NSRect(x: 0, y: 0, width: canvas, height: canvas),
        xRadius: canvas * 0.225,
        yRadius: canvas * 0.225
    )
    NSColor(calibratedRed: 0.20, green: 0.47, blue: 0.98, alpha: 1).setFill()
    bgPath.fill()

    let tint = NSColor.white

    let back = NSBezierPath(
        roundedRect: NSRect(x: 4.3 * s, y: 3.3 * s, width: 11 * s, height: 11.5 * s),
        xRadius: 2 * s,
        yRadius: 2 * s
    )
    back.lineWidth = 1.3 * s
    tint.setStroke()
    back.stroke()

    let front = NSBezierPath(
        roundedRect: NSRect(x: 2.3 * s, y: 1.3 * s, width: 11 * s, height: 11.5 * s),
        xRadius: 2 * s,
        yRadius: 2 * s
    )
    front.lineWidth = 1.5 * s
    tint.setStroke()
    front.stroke()

    let vFont = NSFont.systemFont(ofSize: 8.4 * s, weight: .heavy)
    let vString = NSAttributedString(string: "V", attributes: [.font: vFont, .foregroundColor: tint])
    let vSize = vString.size()
    vString.draw(at: NSPoint(x: 7.8 * s - vSize.width / 2, y: 7.05 * s - vSize.height / 2))

    image.unlockFocus()

    guard let tiff = image.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff),
          let data = rep.representation(using: .png, properties: [:]) else { return }
    try? data.write(to: URL(fileURLWithPath: path))
}

let outDir = CommandLine.arguments[1]
let specs: [(name: String, pixelSize: Int)] = [
    ("icon_16x16", 16), ("icon_16x16@2x", 32),
    ("icon_32x32", 32), ("icon_32x32@2x", 64),
    ("icon_128x128", 128), ("icon_128x128@2x", 256),
    ("icon_256x256", 256), ("icon_256x256@2x", 512),
    ("icon_512x512", 512), ("icon_512x512@2x", 1024)
]

for spec in specs {
    renderIcon(pixelSize: spec.pixelSize, to: "\(outDir)/\(spec.name).png")
}
print("done")
