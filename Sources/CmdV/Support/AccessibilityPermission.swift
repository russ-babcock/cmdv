import AppKit
import ApplicationServices

enum AccessibilityPermission {
    static var isGranted: Bool {
        AXIsProcessTrusted()
    }

    /// Shows the system's own "CmdV would like to control this computer" prompt,
    /// which links straight to System Settings > Privacy & Security > Accessibility.
    /// Without this grant, clips still land on the pasteboard — they just aren't
    /// auto-pasted with a synthetic ⌘V.
    static func promptIfNeeded() {
        // The literal is used instead of the `kAXTrustedCheckOptionPrompt` global so this
        // stays Sendable-safe under strict concurrency; it's a stable, documented constant.
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }

    static func openSystemSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") else { return }
        NSWorkspace.shared.open(url)
    }
}
