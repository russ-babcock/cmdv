import GRDB

enum ClipKind: String, Codable, CaseIterable, DatabaseValueConvertible {
    case text
    case rtf
    case html
    case image
    case fileURL
}
