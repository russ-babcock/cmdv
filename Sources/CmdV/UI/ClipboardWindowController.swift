import AppKit
import SwiftUI

/// Without this, a click on a row right after `previousApp.activate()` has
/// stolen key status back (every paste in Queue Mode does this) is consumed
/// by AppKit just to refocus the panel — the click never reaches the row, so
/// pasting a second or third queued item silently does nothing until you
/// click it again. Accepting first mouse everywhere makes every click live.
private final class FirstMouseHostingView<Content: View>: NSHostingView<Content> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}

@MainActor
final class ClipboardWindowController: NSWindowController {
    private let preferences: Preferences
    private let model: ClipListViewModel
    private let pasteQueue = PasteQueue()
    private let previewController = PreviewOverlayController()
    private var previewedClipID: String?
    private var panel: ClipboardPanel { window as! ClipboardPanel }

    private(set) var previousApp: NSRunningApplication?

    /// Must be retained for as long as the monitor should stay installed —
    /// see `setUpPinKeyMonitor`.
    private var pinKeyMonitor: Any?

    /// The real paste action, wired up to `Paster` by `AppEnvironment`.
    var onActivate: (Clip, Bool) -> Void = { _, _ in }

    /// Wired up to `SettingsWindowController` by `AppEnvironment`.
    var onOpenSettings: () -> Void = {}

    var isVisible: Bool { window?.isVisible ?? false }

    init(clipStore: ClipStore, preferences: Preferences) {
        self.preferences = preferences
        self.model = ClipListViewModel(clipStore: clipStore)

        let panel = ClipboardPanel(contentRect: NSRect(x: 0, y: 0, width: 560, height: 620))
        super.init(window: panel)

        panel.onCancel = { [weak self] in
            guard let self else { return }
            if self.previewController.isVisible {
                self.previewController.hide()
            } else if self.pasteQueue.isActive {
                self.pasteQueue.deactivate()
            } else {
                self.hide()
            }
        }

        panel.onResignKey = { [weak self] in self?.handleResignKey() }

        let view = ClipboardView(
            clipStore: clipStore,
            preferences: preferences,
            model: model,
            pasteQueue: pasteQueue
        ) { [weak self] clip, formatted in
            self?.performPaste(clip, formatted: formatted)
        } onPreview: { [weak self] clip in
            self?.showPreview(clip)
        } onOpenSettings: { [weak self] in
            self?.onOpenSettings()
        }
        panel.contentView = FirstMouseHostingView(rootView: view)

        previewController.onDismiss = { [weak self] in self?.previewController.hide() }
        previewController.onNavigate = { [weak self] direction in self?.navigatePreview(direction) }

        // The panel can sit open while the user switches to a different app
        // before turning queue mode on (e.g. opened while a browser was
        // frontmost, then the user clicks over to Word and hits ⌘K) — without
        // this, `previousApp` would still point at the browser from `show()`
        // and every queued paste would land there instead of Word.
        pasteQueue.onActivate = { [weak self] in
            self?.previousApp = NSWorkspace.shared.frontmostApplication
        }

        setUpPinKeyMonitor()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func toggle() {
        if isVisible {
            hide()
        } else {
            show()
        }
    }

    func show() {
        previousApp = NSWorkspace.shared.frontmostApplication
        model.refresh()

        let origin = WindowPositioner.origin(for: panel.frame.size, mode: preferences.windowPositionMode)
        panel.setFrameOrigin(origin)
        panel.makeKeyAndOrderFront(nil)
    }

    func hide() {
        previewController.hide()
        pasteQueue.deactivate()
        panel.orderOut(nil)
    }

    /// Called after a background purge (expired concealed clips) actually
    /// removes something, so an open window doesn't show a stale row.
    func refreshIfVisible() {
        guard isVisible else { return }
        model.refresh()
    }

    /// Auto-closes the window when it loses key status to something outside
    /// the app — but not while Queue Mode is active (a session shouldn't die
    /// just because focus briefly moved), and not when the new key window is
    /// our own preview overlay, which legitimately steals key status the
    /// instant it opens. Deferred a tick so the new key window (if any) is
    /// already established by the time we check.
    private func handleResignKey() {
        DispatchQueue.main.async { [weak self] in
            guard let self, !self.pasteQueue.isActive else { return }
            let keyWindow = NSApp.keyWindow
            guard keyWindow !== self.panel, keyWindow !== self.previewController.window else { return }
            self.hide()
        }
    }

    private func performPaste(_ clip: Clip, formatted: Bool) {
        if pasteQueue.isActive {
            // Hide (not just resign key) for the same reason single-paste mode
            // does: it's the only way to *unambiguously* hand key status to
            // `previousApp` before the synthetic ⌘V fires. Re-shown after the
            // paste completes so the session still reads as "the window
            // stayed open" despite the brief blink.
            panel.orderOut(nil)
            onActivate(clip, formatted)
            pasteQueue.recordPaste(clip.id)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
                guard let self, self.pasteQueue.isActive else { return }
                self.panel.orderFront(nil)
            }
        } else {
            hide()
            onActivate(clip, formatted)
        }
    }

    /// SwiftUI's `List` is backed by a real `NSTableView`, which has its own
    /// built-in type-select behavior: a bare `1`-`9`/`A`-`Z` keystroke is
    /// consumed by the table to jump-scroll to a matching row *before* it
    /// ever reaches `ClipboardView`'s `.onKeyPress` — so pin activation can
    /// never fire from there. A local event monitor sees the keystroke at the
    /// application level, ahead of that table-view handling, so it can steal
    /// exactly the keys pin activation cares about and let everything else
    /// (arrow keys, ⌘-shortcuts, and any typing in the search field) through
    /// untouched.
    private func setUpPinKeyMonitor() {
        pinKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, self.panel.isKeyWindow else { return event }
            return self.handlePinKeyEvent(event) ? nil : event
        }
    }

    private func handlePinKeyEvent(_ event: NSEvent) -> Bool {
        // Auto-repeat resends keyDown for as long as a key is held; without
        // this, a press that lingers even slightly pastes the same clip twice.
        guard !event.isARepeat else { return false }

        // A field editor (search field, etc.) currently has focus — let the
        // keystroke through so it types normally instead of firing a pin.
        if panel.firstResponder is NSText { return false }

        guard let characters = event.charactersIgnoringModifiers, !characters.isEmpty else { return false }
        // `.numericPad` is part of `deviceIndependentFlagsMask` but isn't a
        // real modifier — without excluding it, every keypad digit would look
        // "modified" and never pass the bare-key check.
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask).subtracting([.capsLock, .numericPad])

        switch preferences.pinActivation {
        case .bareKey:
            guard flags.isEmpty else { return false }
        case .controlKey:
            guard flags == .control else { return false }
        }

        guard let key = PinKey.normalize(characters), let clip = model.clip(atEffectiveKey: key) else {
            return false
        }
        performPaste(clip, formatted: false)
        return true
    }

    private func showPreview(_ clip: Clip) {
        previewedClipID = clip.id
        previewController.show(clip: clip, anchorScreen: panel.screen)
    }

    private func navigatePreview(_ direction: PreviewNavigationDirection) {
        let clips = model.filteredClips
        guard let currentIndex = clips.firstIndex(where: { $0.id == previewedClipID }) else { return }

        let newIndex: Int
        switch direction {
        case .previous: newIndex = currentIndex - 1
        case .next: newIndex = currentIndex + 1
        }
        guard clips.indices.contains(newIndex) else { return }

        let next = clips[newIndex]
        model.selectedClipID = next.id
        showPreview(next)
    }
}
