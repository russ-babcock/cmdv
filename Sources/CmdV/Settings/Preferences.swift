import Foundation
import Observation

/// UserDefaults-backed settings shared across the capture pipeline, the window,
/// and the Settings UI that edits them.
@MainActor
@Observable
final class Preferences {
    enum WindowPositionMode: String, Codable, CaseIterable {
        case cursor
        case centered
    }

    /// How a bare `1`-`9`/`A`-`Z` keypress is interpreted while the clipboard
    /// window is open. `.bareKey` needs the list (not the search field) focused;
    /// `.controlKey` works anywhere by requiring the Control modifier.
    enum PinActivationMode: String, Codable, CaseIterable {
        case bareKey
        case controlKey
    }

    enum AppearanceMode: String, Codable, CaseIterable {
        case system
        case light
        case dark

        var label: String {
            switch self {
            case .system: "System"
            case .light: "Light"
            case .dark: "Dark"
            }
        }
    }

    private enum Keys {
        static let historyLimit = "historyLimit"
        static let pollInterval = "pollInterval"
        static let windowPositionMode = "windowPositionMode"
        static let hotkey = "hotkey"
        static let pinActivation = "pinActivation"
        static let launchAtLogin = "launchAtLogin"
        static let showMenuBarIcon = "showMenuBarIcon"
        static let appearance = "appearance"
        static let ignoredBundleIDs = "ignoredBundleIDs"
    }

    private let defaults: UserDefaults

    var historyLimit: Int {
        didSet { defaults.set(historyLimit, forKey: Keys.historyLimit) }
    }

    var pollInterval: TimeInterval {
        didSet { defaults.set(pollInterval, forKey: Keys.pollInterval) }
    }

    var windowPositionMode: WindowPositionMode {
        didSet { defaults.set(windowPositionMode.rawValue, forKey: Keys.windowPositionMode) }
    }

    var hotkey: KeyCombo {
        didSet {
            if let data = try? JSONEncoder().encode(hotkey) {
                defaults.set(data, forKey: Keys.hotkey)
            }
        }
    }

    var pinActivation: PinActivationMode {
        didSet { defaults.set(pinActivation.rawValue, forKey: Keys.pinActivation) }
    }

    var launchAtLogin: Bool {
        didSet { defaults.set(launchAtLogin, forKey: Keys.launchAtLogin) }
    }

    var showMenuBarIcon: Bool {
        didSet { defaults.set(showMenuBarIcon, forKey: Keys.showMenuBarIcon) }
    }

    var appearance: AppearanceMode {
        didSet { defaults.set(appearance.rawValue, forKey: Keys.appearance) }
    }

    var ignoredBundleIDs: Set<String> {
        didSet { defaults.set(Array(ignoredBundleIDs), forKey: Keys.ignoredBundleIDs) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        self.historyLimit = defaults.object(forKey: Keys.historyLimit) as? Int ?? 50
        self.pollInterval = defaults.object(forKey: Keys.pollInterval) as? Double ?? 0.25
        self.windowPositionMode = (defaults.string(forKey: Keys.windowPositionMode))
            .flatMap(WindowPositionMode.init(rawValue:)) ?? .cursor
        self.pinActivation = (defaults.string(forKey: Keys.pinActivation))
            .flatMap(PinActivationMode.init(rawValue:)) ?? .bareKey
        self.launchAtLogin = defaults.object(forKey: Keys.launchAtLogin) as? Bool ?? true
        self.showMenuBarIcon = defaults.object(forKey: Keys.showMenuBarIcon) as? Bool ?? true
        self.appearance = (defaults.string(forKey: Keys.appearance))
            .flatMap(AppearanceMode.init(rawValue:)) ?? .system
        self.ignoredBundleIDs = Set(defaults.stringArray(forKey: Keys.ignoredBundleIDs) ?? [])

        if let data = defaults.data(forKey: Keys.hotkey),
           let combo = try? JSONDecoder().decode(KeyCombo.self, from: data) {
            self.hotkey = combo
        } else {
            self.hotkey = .default
        }
    }
}
