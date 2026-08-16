import AppKit
import SwiftUI

enum PreviewNavigationDirection {
    case previous
    case next
}

/// A Quick Look-style floating panel: Space or right-click → Preview opens it over
/// the selected row, sized to the clip's content and centered on the clipboard
/// window's screen. Space/Esc/click-outside dismiss; ↑/↓ walk the list without
/// closing it.
@MainActor
final class PreviewOverlayController: NSWindowController {
    private var panel: NSPanel { window as! NSPanel }

    var onDismiss: (() -> Void)?
    var onNavigate: ((PreviewNavigationDirection) -> Void)?

    init() {
        let panel = NSPanel(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.hasShadow = true
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        super.init(window: panel)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func show(clip: Clip, anchorScreen: NSScreen?) {
        let contentSize = Self.contentSize(for: clip, in: anchorScreen)

        let view = PreviewOverlayView(
            clip: clip,
            onDismiss: { [weak self] in self?.onDismiss?() },
            onNavigate: { [weak self] direction in self?.onNavigate?(direction) }
        )
        panel.contentView = NSHostingView(rootView: view)
        panel.setContentSize(contentSize)

        let screenFrame = anchorScreen?.visibleFrame ?? NSScreen.main?.visibleFrame ?? CGRect(x: 0, y: 0, width: 1440, height: 900)
        let origin = CGPoint(
            x: screenFrame.midX - contentSize.width / 2,
            y: screenFrame.midY - contentSize.height / 2
        )
        panel.setFrameOrigin(origin)
        panel.makeKeyAndOrderFront(nil)
    }

    func hide() {
        panel.orderOut(nil)
    }

    var isVisible: Bool { window?.isVisible ?? false }

    static func contentSize(for clip: Clip, in screen: NSScreen?) -> CGSize {
        let visibleFrame = screen?.visibleFrame ?? CGRect(x: 0, y: 0, width: 1440, height: 900)
        let maxSize = CGSize(width: visibleFrame.width * 0.8, height: visibleFrame.height * 0.8)
        let footerHeight: CGFloat = 32

        if clip.kind == .image, let width = clip.pixelWidth, let height = clip.pixelHeight, width > 0, height > 0 {
            let fitted = fitSize(
                natural: CGSize(width: CGFloat(width), height: CGFloat(height)),
                max: CGSize(width: maxSize.width, height: maxSize.height - footerHeight)
            )
            return CGSize(width: fitted.width, height: fitted.height + footerHeight)
        }

        return CGSize(width: min(560, maxSize.width), height: min(480, maxSize.height))
    }

    /// Pure geometry: scales `natural` down to fit inside `max`, preserving aspect
    /// ratio, but never scales up — a small image stays at its real size.
    nonisolated static func fitSize(natural: CGSize, max maxSize: CGSize) -> CGSize {
        guard natural.width > 0, natural.height > 0 else { return maxSize }
        guard natural.width > maxSize.width || natural.height > maxSize.height else { return natural }

        let scale = min(maxSize.width / natural.width, maxSize.height / natural.height)
        return CGSize(width: natural.width * scale, height: natural.height * scale)
    }
}
