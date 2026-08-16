import AppKit

/// Owns the app's lifecycle as a background accessory process: no Dock icon,
/// no main menu bar, reachable only via the menu bar extra and the global hotkey.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    /// Created immediately (not inside `applicationDidFinishLaunching`) so
    /// `CmdVApp`'s very first `body` evaluation — building the `MenuBarExtra`'s
    /// `isInserted` binding — already has something to read.
    let preferences = Preferences()

    private(set) var environment: AppEnvironment!

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        do {
            let environment = try AppEnvironment(preferences: preferences)
            self.environment = environment
            environment.clipboardMonitor.start()
        } catch {
            NSLog("CmdV: failed to initialize storage: \(error)")
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        // A background agent must never quit just because its one visible window closed.
        false
    }
}
