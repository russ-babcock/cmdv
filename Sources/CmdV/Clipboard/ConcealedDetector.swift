import AppKit

/// Flags clips that should be auto-purged after 60 seconds: the pasteboard's
/// own "don't persist me" marker, plus a best-effort list of password manager
/// bundle IDs for apps that might not set it on every copy. The flag is the
/// authoritative signal; the bundle ID list is a supplementary catch-all.
enum ConcealedDetector {
    static let concealedPasteboardType = NSPasteboard.PasteboardType("org.nspasteboard.ConcealedType")

    static let passwordManagerBundleIDs: Set<String> = [
        "com.1password.1password",
        "com.agilebits.onepassword7",
        "com.agilebits.onepassword4",
        "com.bitwarden.desktop",
        "org.keepassxc.KeePassXC",
        "com.apple.keychainaccess",
        "com.apple.Passwords",
        "com.dashlane.dashlanephonefinal",
        "com.dashlane.Dashlane",
        "com.lastpass.LastPass",
        "me.proton.pass",
        "com.markmcguill.strongbox",
        "com.strongbox.mac"
    ]

    /// A copy made from a password manager's *browser extension* (its own
    /// popup, not a page it's acting on) reports the browser itself as the
    /// source app — the bundle ID list above can't see past that. Chromium
    /// browsers additionally put the originating page's URL on the pasteboard
    /// as `org.chromium.source-url`; for an extension popup that's a
    /// `chrome-extension://<id>/...` URL, so matching the extension ID is a
    /// reliable, content-free signal. Confirmed empirically per-extension —
    /// add more here as they're found (copy from that extension, check what
    /// `org.chromium.source-url` reports).
    static let passwordManagerExtensionIDs: Set<String> = [
        "aeblfdkhhhdcdjpifhhbdiojplfjncoa" // 1Password
    ]

    static func isConcealed(types: [NSPasteboard.PasteboardType], sourceBundleID: String?, sourceURL: String? = nil) -> Bool {
        if types.contains(concealedPasteboardType) { return true }
        if let sourceBundleID, passwordManagerBundleIDs.contains(sourceBundleID) { return true }
        if let sourceURL, let extensionID = chromeExtensionID(from: sourceURL), passwordManagerExtensionIDs.contains(extensionID) {
            return true
        }
        return false
    }

    private static func chromeExtensionID(from urlString: String) -> String? {
        guard urlString.hasPrefix("chrome-extension://") else { return nil }
        return urlString.dropFirst("chrome-extension://".count).split(separator: "/").first.map(String.init)
    }
}
