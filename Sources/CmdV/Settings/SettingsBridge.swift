import AppKit
import SwiftUI

/// Opens the app's `Settings` scene from code that isn't part of that scene's
/// SwiftUI environment — like the clipboard window's gear button, which lives
/// in a hand-built `NSPanel` outside the declared Scene graph, so
/// `@Environment(\.openSettings)` is never populated there.
///
/// `CmdVApp`'s menu bar label captures the real `openSettings` action into
/// `SettingsOpener.shared` as soon as it appears (which happens at launch,
/// before the user can ever click the gear). That's the primary path. The
/// `showSettingsWindow:` selector is kept only as a last-resort fallback for
/// the (should-be-impossible) case where the capture never ran — it's
/// undocumented AppKit behavior that doesn't reliably fire for accessory
/// (no-Dock-icon) apps.
enum SettingsBridge {
    @MainActor
    static func open() {
        NSApp.activate()
        if let action = SettingsOpener.shared.action {
            action()
        } else {
            NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        }
    }
}

@MainActor
final class SettingsOpener {
    static let shared = SettingsOpener()
    var action: OpenSettingsAction?
}

/// Zero-size view whose only job is to capture `openSettings` into
/// `SettingsOpener.shared`. Attached to the menu bar label so the capture
/// runs the moment the icon renders, not only when the menu is opened.
struct SettingsOpenerCapture: View {
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        Color.clear
            .frame(width: 0, height: 0)
            .onAppear { SettingsOpener.shared.action = openSettings }
    }
}
