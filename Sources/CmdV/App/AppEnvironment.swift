import Foundation
import GRDB

/// The app's shared dependency graph, owned by `AppDelegate` and handed to
/// SwiftUI views. `preferences` is created earlier by `AppDelegate` (before this
/// object exists) so the menu bar icon's visibility binding is available from
/// the very first `CmdVApp.body` evaluation.
@MainActor
final class AppEnvironment {
    let dbQueue: DatabaseQueue
    let clipStore: ClipStore
    let preferences: Preferences
    let clipboardMonitor: ClipboardMonitor
    let hotkeyManager: HotkeyManager
    let windowController: ClipboardWindowController
    let paster: Paster

    init(preferences: Preferences) throws {
        let dbQueue = try AppDatabase.makeQueue()
        let clipStore = ClipStore(dbQueue: dbQueue)
        let windowController = ClipboardWindowController(clipStore: clipStore, preferences: preferences)
        let hotkeyManager = HotkeyManager()
        let clipboardMonitor = ClipboardMonitor(clipStore: clipStore, preferences: preferences)
        let paster = Paster(clipStore: clipStore, clipboardMonitor: clipboardMonitor)

        self.dbQueue = dbQueue
        self.clipStore = clipStore
        self.preferences = preferences
        self.clipboardMonitor = clipboardMonitor
        self.hotkeyManager = hotkeyManager
        self.windowController = windowController
        self.paster = paster

        LoginItem.setEnabled(preferences.launchAtLogin)
        AppAppearance.apply(preferences.appearance)

        hotkeyManager.onTrigger = { [weak windowController] in
            windowController?.toggle()
        }
        if !hotkeyManager.register(preferences.hotkey) {
            NSLog("CmdV: failed to register hotkey \(preferences.hotkey.displayString) — likely already claimed by another app")
        }

        windowController.onActivate = { [weak windowController, weak paster] clip, formatted in
            paster?.paste(clip, formatted: formatted, into: windowController?.previousApp)
        }
        windowController.onOpenSettings = {
            SettingsBridge.open()
        }

        clipboardMonitor.onPurge = { [weak windowController] in
            windowController?.refreshIfVisible()
        }
    }
}
