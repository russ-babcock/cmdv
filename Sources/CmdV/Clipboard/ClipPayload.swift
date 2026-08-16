import Foundation

/// Everything `ClipboardMonitor` extracted from the pasteboard for one capture,
/// with any file I/O (image/thumbnail/payload writes) already done. `ClipStore`
/// turns this into a persisted `Clip` row.
struct ClipPayload {
    var kind: ClipKind
    var plainText: String?
    var previewText: String
    var payloadPath: String?

    var imagePath: String?
    var thumbPath: String?
    var pixelWidth: Int?
    var pixelHeight: Int?
    var byteSize: Int?

    var sourceBundleID: String?
    var sourceAppName: String?

    var isConcealed: Bool = false
    var expiresAt: Date? = nil

    var contentHash: String

    func makeClip() -> Clip {
        Clip(
            kind: kind,
            plainText: plainText,
            previewText: previewText,
            payloadPath: payloadPath,
            imagePath: imagePath,
            thumbPath: thumbPath,
            pixelWidth: pixelWidth,
            pixelHeight: pixelHeight,
            byteSize: byteSize,
            sourceBundleID: sourceBundleID,
            sourceAppName: sourceAppName,
            isConcealed: isConcealed,
            expiresAt: expiresAt,
            contentHash: contentHash
        )
    }
}
