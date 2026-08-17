import SwiftUI

@main
struct CmdVApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra(isInserted: Binding(
            get: { appDelegate.preferences.showMenuBarIcon },
            set: { appDelegate.preferences.showMenuBarIcon = $0 }
        )) {
            Button("Open Clipboard History") {
                appDelegate.environment?.windowController.toggle()
            }
            .keyboardShortcut("v", modifiers: [.command, .shift])

            Divider()

            Button("Check for Updates…") {
                appDelegate.updater.checkForUpdates()
            }
            .disabled(!appDelegate.updater.canCheckForUpdates)

            SettingsLink {
                Text("Settings…")
            }
            .keyboardShortcut(",", modifiers: [.command])

            Divider()

            Button("Quit CmdV") {
                NSApp.terminate(nil)
            }
            .keyboardShortcut("q", modifiers: [.command])
        } label: {
            Image(nsImage: MenuBarIcon.make())
                .background(SettingsOpenerCapture())
        }

        // A real Settings scene, not a hand-built window: this is what gives
        // the tab strip its native "System Settings" chrome for free. The
        // clipboard window's gear button can't use `openSettings()` (it lives
        // outside this Scene graph, see ClipboardView), so it reaches this
        // same scene via the AppKit selector `openSettings()` is built on top
        // of — see `SettingsBridge.open()`.
        Settings {
            SettingsView(
                preferences: appDelegate.preferences,
                updater: appDelegate.updater,
                attemptHotkey: { combo in
                    appDelegate.environment?.hotkeyManager.register(combo) ?? false
                },
                restartMonitoring: {
                    appDelegate.environment?.clipboardMonitor.start()
                }
            )
        }
    }
}
