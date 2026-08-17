import AppKit

/// Icons for clip rows. Every lookup here hits the filesystem, so results —
/// including misses, for apps or files that are no longer there — are cached
/// for the life of the process.
@MainActor
enum IconCache {
    private static var appIcons: [String: NSImage?] = [:]
    private static var fileIcons: [String: NSImage] = [:]

    /// The icon of the app a clip was copied from, for the source line.
    static func appIcon(forBundleID bundleID: String) -> NSImage? {
        if let cached = appIcons[bundleID] { return cached }
        let icon = NSWorkspace.shared
            .urlForApplication(withBundleIdentifier: bundleID)
            .map { NSWorkspace.shared.icon(forFile: $0.path) }
        appIcons[bundleID] = icon
        return icon
    }

    /// The Finder icon of a copied file — a PDF looks like a PDF, a folder like
    /// a folder. This is what makes a file row unmistakably not a text row, far
    /// more than any two document glyphs could.
    ///
    /// `icon(forFile:)` answers for paths that no longer exist too, with the
    /// generic document icon, which is the right thing to show for a clip whose
    /// file has since been moved or deleted.
    static func fileIcon(atPath path: String) -> NSImage {
        if let cached = fileIcons[path] { return cached }
        let icon = NSWorkspace.shared.icon(forFile: path)
        fileIcons[path] = icon
        return icon
    }
}
