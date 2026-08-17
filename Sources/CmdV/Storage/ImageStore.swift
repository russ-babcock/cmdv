import Foundation
import ImageIO
import UniformTypeIdentifiers

enum ImageStore {
    struct SavedImage {
        let imagePath: String
        let thumbPath: String
        let pixelWidth: Int
        let pixelHeight: Int
        let byteSize: Int
    }

    private static let thumbnailMaxPixelSize = 256 // 128pt at 2x

    /// Writes the original image (re-encoded as PNG for consistent storage) plus a
    /// downsampled thumbnail, both named after the clip's id.
    static func saveImage(data: Data, clipID: String) throws -> SavedImage {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            throw ImageStoreError.decodeFailed
        }

        let imageURL = AppPaths.imagesDirectory.appendingPathComponent("\(clipID).png")
        let thumbURL = AppPaths.imagesDirectory.appendingPathComponent("\(clipID)_thumb.png")

        try write(image, to: imageURL)

        let thumbOptions: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceThumbnailMaxPixelSize: thumbnailMaxPixelSize,
            kCGImageSourceCreateThumbnailWithTransform: true
        ]
        guard let thumbnail = CGImageSourceCreateThumbnailAtIndex(source, 0, thumbOptions as CFDictionary) else {
            throw ImageStoreError.thumbnailFailed
        }
        try write(thumbnail, to: thumbURL)

        let attributes = try? FileManager.default.attributesOfItem(atPath: imageURL.path)
        let byteSize = (attributes?[.size] as? Int) ?? data.count

        return SavedImage(
            imagePath: imageURL.path,
            thumbPath: thumbURL.path,
            pixelWidth: image.width,
            pixelHeight: image.height,
            byteSize: byteSize
        )
    }

    static func savePayload(_ representations: [String: Data], clipID: String) throws -> String {
        let url = AppPaths.payloadsDirectory.appendingPathComponent("\(clipID).plist")
        let plistData = try PropertyListSerialization.data(
            fromPropertyList: representations,
            format: .binary,
            options: 0
        )
        try plistData.write(to: url, options: .atomic)
        restrictPermissions(of: url)
        return url.path
    }

    static func loadPayload(at path: String) -> [String: Data]? {
        guard let data = FileManager.default.contents(atPath: path) else { return nil }
        return try? PropertyListSerialization.propertyList(
            from: data,
            options: [],
            format: nil
        ) as? [String: Data]
    }

    static func deleteFiles(for clip: Clip) {
        let fm = FileManager.default
        for path in [clip.imagePath, clip.thumbPath, clip.payloadPath].compactMap({ $0 }) {
            try? fm.removeItem(atPath: path)
        }
    }

    private static func write(_ image: CGImage, to url: URL) throws {
        guard let destination = CGImageDestinationCreateWithURL(
            url as CFURL, UTType.png.identifier as CFString, 1, nil
        ) else {
            throw ImageStoreError.writeFailed
        }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else {
            throw ImageStoreError.writeFailed
        }
        restrictPermissions(of: url)
    }

    /// Copied content is written owner-only. The enclosing directory is already
    /// 0700, so this is defence in depth — it also covers the case of a file
    /// being moved or copied out of that directory later.
    private static func restrictPermissions(of url: URL) {
        try? FileManager.default.setAttributes(AppPaths.fileAttributes, ofItemAtPath: url.path)
    }
}

enum ImageStoreError: Error {
    case decodeFailed
    case thumbnailFailed
    case writeFailed
}
