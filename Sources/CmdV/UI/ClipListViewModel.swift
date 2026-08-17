import Foundation
import Observation

enum SidebarFilter: String, CaseIterable, Identifiable {
    case all = "All"
    case favorites = "Favorites"
    case pinned = "Pinned"
    case images = "Images"
    case text = "Text"
    case files = "Files"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .all: "tray.full"
        case .favorites: "star"
        case .pinned: "pin"
        case .images: "photo"
        case .text: "text.alignleft"
        case .files: "folder"
        }
    }
}

@MainActor
@Observable
final class ClipListViewModel {
    private let clipStore: ClipStore

    var clips: [Clip] = []
    var searchText: String = ""
    var sidebarFilter: SidebarFilter = .all
    var selectedClipID: String?

    var filteredClips: [Clip] {
        var result = clips
        switch sidebarFilter {
        case .all: break
        case .favorites: result = result.filter(\.isFavorite)
        case .pinned: result = result.filter { $0.pinKey != nil }
        case .images: result = result.filter { $0.kind == .image }
        // Copied files used to fall under Text, for want of anywhere better.
        // Now that they have their own filter, Text means text.
        case .text: result = result.filter { $0.kind == .text || $0.kind == .rtf || $0.kind == .html }
        case .files: result = result.filter { $0.kind == .fileURL }
        }

        guard !searchText.isEmpty else { return result }
        return result.filter {
            ($0.plainText ?? $0.previewText)
                .localizedCaseInsensitiveContains(searchText)
        }
    }

    init(clipStore: ClipStore) {
        self.clipStore = clipStore
    }

    /// The key each visible clip currently shows: a manually locked (persisted)
    /// pin keeps its key permanently, reserving it out of the pool; every other
    /// clip is auto-numbered by its position in `filteredClips`, skipping keys
    /// already reserved by a locked pin.
    var effectivePinKeys: [String: String] {
        var result: [String: String] = [:]
        var reserved: Set<String> = []

        for clip in filteredClips {
            if let pinKey = clip.pinKey {
                result[clip.id] = pinKey
                reserved.insert(pinKey)
            }
        }

        var candidates = PinKey.allowedCharacters.makeIterator()
        for clip in filteredClips where clip.pinKey == nil {
            while let candidate = candidates.next() {
                let key = String(candidate)
                guard !reserved.contains(key) else { continue }
                result[clip.id] = key
                reserved.insert(key)
                break
            }
        }

        return result
    }

    func clip(atEffectiveKey key: String) -> Clip? {
        let keys = effectivePinKeys
        guard let id = keys.first(where: { $0.value == key })?.key else { return nil }
        return filteredClips.first { $0.id == id }
    }

    func refresh() {
        clips = (try? clipStore.fetchAll()) ?? []
        if let selectedClipID, !clips.contains(where: { $0.id == selectedClipID }) {
            self.selectedClipID = nil
        }
    }
}
