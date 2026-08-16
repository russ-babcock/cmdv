import AppKit

/// The clip list's window. A non-activating panel rather than a `WindowGroup`
/// window: it can be shown and clicked without stealing key focus from whatever
/// app the user is about to paste into — required later for queue mode, useful
/// even in single-paste mode since it avoids an activate/deactivate flicker.
final class ClipboardPanel: NSPanel {
    var onCancel: (() -> Void)?
    var onResignKey: (() -> Void)?

    init(contentRect: NSRect) {
        super.init(
            contentRect: contentRect,
            // Deliberately no `.fullSizeContentView`: that option lets the
            // content view extend up underneath the titlebar, which is why
            // scrolled clip rows rendered behind the toolbar controls. Without
            // it AppKit insets the content below the titlebar, so the list
            // gets a real container it cannot scroll out of.
            styleMask: [.titled, .resizable, .nonactivatingPanel, .closable],
            backing: .buffered,
            defer: false
        )

        isFloatingPanel = true
        level = .floating
        collectionBehavior = [.fullScreenAuxiliary, .moveToActiveSpace]
        // Opaque so the titlebar draws its standard backing material rather
        // than showing whatever sits behind the panel. `titleVisibility`
        // above still suppresses the title text, so the frame stays clean.
        titlebarAppearsTransparent = false
        isMovableByWindowBackground = true
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    override func cancelOperation(_ sender: Any?) {
        onCancel?()
    }

    override func resignKey() {
        super.resignKey()
        onResignKey?()
    }
}
