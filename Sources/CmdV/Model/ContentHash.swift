import CryptoKit
import Foundation

/// The identity of a clip's content. Two clips with the same hash are the same
/// copy as far as the history is concerned, which is how a repeat copy is
/// recognised instead of stacking up duplicates.
///
/// Shared rather than private to `ClipboardMonitor` because editing a clip has
/// to produce the hash the monitor *would* have produced for that text — an
/// edited clip whose hash didn't match would look like new content the next
/// time the same thing was copied.
enum ContentHash {
    static func of(_ data: Data) -> String {
        SHA256.hash(data: data).compactMap { String(format: "%02x", $0) }.joined()
    }

    static func of(_ string: String) -> String {
        of(Data(string.utf8))
    }
}
