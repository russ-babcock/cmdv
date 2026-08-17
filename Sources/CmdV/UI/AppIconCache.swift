import AppKit

/// Source-app icons for clip rows. Looking an icon up hits the filesystem, so
/// results (including misses, for apps that are no longer installed) are cached
/// for the life of the process.
@MainActor
enum AppIconCache {
    private static var cache: [String: NSImage?] = [:]

    static func icon(forBundleID bundleID: String) -> NSImage? {
        if let cached = cache[bundleID] { return cached }
        let icon = NSWorkspace.shared
            .urlForApplication(withBundleIdentifier: bundleID)
            .map { NSWorkspace.shared.icon(forFile: $0.path) }
        cache[bundleID] = icon
        return icon
    }
}
