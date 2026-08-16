import Foundation
import GRDB

struct Clip: Identifiable, Codable, Hashable {
    var id: String
    var createdAt: Date
    var lastUsedAt: Date
    var useCount: Int

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

    var isFavorite: Bool
    var pinKey: String?

    var isConcealed: Bool
    var expiresAt: Date?

    var contentHash: String

    init(
        id: String = UUID().uuidString,
        createdAt: Date = Date(),
        lastUsedAt: Date = Date(),
        useCount: Int = 0,
        kind: ClipKind,
        plainText: String? = nil,
        previewText: String,
        payloadPath: String? = nil,
        imagePath: String? = nil,
        thumbPath: String? = nil,
        pixelWidth: Int? = nil,
        pixelHeight: Int? = nil,
        byteSize: Int? = nil,
        sourceBundleID: String? = nil,
        sourceAppName: String? = nil,
        isFavorite: Bool = false,
        pinKey: String? = nil,
        isConcealed: Bool = false,
        expiresAt: Date? = nil,
        contentHash: String
    ) {
        self.id = id
        self.createdAt = createdAt
        self.lastUsedAt = lastUsedAt
        self.useCount = useCount
        self.kind = kind
        self.plainText = plainText
        self.previewText = previewText
        self.payloadPath = payloadPath
        self.imagePath = imagePath
        self.thumbPath = thumbPath
        self.pixelWidth = pixelWidth
        self.pixelHeight = pixelHeight
        self.byteSize = byteSize
        self.sourceBundleID = sourceBundleID
        self.sourceAppName = sourceAppName
        self.isFavorite = isFavorite
        self.pinKey = pinKey
        self.isConcealed = isConcealed
        self.expiresAt = expiresAt
        self.contentHash = contentHash
    }
}

extension Clip: FetchableRecord, MutablePersistableRecord {
    static let databaseTableName = "clip"
}
