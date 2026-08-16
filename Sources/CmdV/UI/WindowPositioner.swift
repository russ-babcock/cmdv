import AppKit

enum WindowPositioner {
    /// Where to place a window of `windowSize`, given the current mouse location
    /// and connected screens. Always clamped to the target screen's visible frame
    /// so the window can never end up partly offscreen.
    static func origin(
        for windowSize: CGSize,
        mode: Preferences.WindowPositionMode,
        mouseLocation: CGPoint = NSEvent.mouseLocation,
        screens: [NSScreen] = NSScreen.screens
    ) -> CGPoint {
        let visibleFrame = (screens.first { $0.frame.contains(mouseLocation) } ?? screens.first)?
            .visibleFrame ?? CGRect(x: 0, y: 0, width: 1440, height: 900)

        switch mode {
        case .cursor:
            let raw = CGPoint(x: mouseLocation.x, y: mouseLocation.y - windowSize.height)
            return clamp(origin: raw, size: windowSize, in: visibleFrame)
        case .centered:
            let raw = CGPoint(
                x: visibleFrame.midX - windowSize.width / 2,
                y: visibleFrame.midY - windowSize.height / 2
            )
            return clamp(origin: raw, size: windowSize, in: visibleFrame)
        }
    }

    /// Pure geometry: pins `origin` so a `size`-sized rect stays fully inside `frame`.
    static func clamp(origin: CGPoint, size: CGSize, in frame: CGRect) -> CGPoint {
        let maxX = max(frame.minX, frame.maxX - size.width)
        let maxY = max(frame.minY, frame.maxY - size.height)
        return CGPoint(
            x: min(max(origin.x, frame.minX), maxX),
            y: min(max(origin.y, frame.minY), maxY)
        )
    }
}
