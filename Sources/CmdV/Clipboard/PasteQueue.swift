import Observation

/// Tracks "click each clip in the order you want it pasted" mode: the window
/// stays open, each click pastes into the target app, and pasted rows get a
/// dimmed ✓ + order badge so you can see what's left.
@MainActor
@Observable
final class PasteQueue {
    private(set) var isActive = false
    private(set) var pasteOrder: [String: Int] = [:]
    private var nextOrder = 1

    var pastedCount: Int { pasteOrder.count }

    /// Fired when queue mode turns on, so the owner can re-capture whatever
    /// app is frontmost *now* rather than trusting whatever was frontmost
    /// when the panel first opened — those can diverge if the panel was left
    /// open while the user switched to a different target app.
    var onActivate: () -> Void = {}

    func order(for clipID: String) -> Int? {
        pasteOrder[clipID]
    }

    func activate() {
        isActive = true
        onActivate()
    }

    /// Turns queue mode off and clears badges — the state on ⌘K-again, Esc, or
    /// the window closing.
    func deactivate() {
        isActive = false
        reset()
    }

    func toggle() {
        isActive ? deactivate() : activate()
    }

    func recordPaste(_ clipID: String) {
        pasteOrder[clipID] = nextOrder
        nextOrder += 1
    }

    func reset() {
        pasteOrder = [:]
        nextOrder = 1
    }
}
