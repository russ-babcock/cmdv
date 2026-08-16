import Foundation

/// A pin is a single character, `1`-`9` or `A`-`Z`, bound to one clip so it can be
/// recalled by pressing that key while the clipboard window is open.
enum PinKey {
    static let allowedCharacters: [Character] =
        Array("123456789") + Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ")

    static func isValid(_ value: String) -> Bool {
        value.count == 1 && allowedCharacters.contains(Character(value.uppercased()))
    }

    static func normalize(_ value: String) -> String? {
        guard isValid(value) else { return nil }
        return value.uppercased()
    }
}
