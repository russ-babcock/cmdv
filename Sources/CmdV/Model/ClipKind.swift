import GRDB

enum ClipKind: String, Codable, DatabaseValueConvertible {
    case text
    case rtf
    case html
    case image
    case fileURL
}
