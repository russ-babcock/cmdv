import Foundation
import Testing
@testable import CmdV

@MainActor
@Suite struct PreferencesTests {
    private func makeDefaults() -> UserDefaults {
        let suiteName = "com.babcock.cmdv.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }

    @Test func hotkeyRoundTripsThroughUserDefaults() {
        let defaults = makeDefaults()
        let custom = KeyCombo(keyCode: 11, carbonModifiers: 4352)

        let first = Preferences(defaults: defaults)
        first.hotkey = custom

        let second = Preferences(defaults: defaults)
        #expect(second.hotkey == custom)
    }

    @Test func missingDefaultsFallBackToDefaultHotkey() {
        let defaults = makeDefaults()
        let preferences = Preferences(defaults: defaults)
        #expect(preferences.hotkey == KeyCombo.default)
    }

    @Test func ignoredBundleIDsRoundTrip() {
        let defaults = makeDefaults()

        let first = Preferences(defaults: defaults)
        first.ignoredBundleIDs = ["com.apple.keychainaccess", "com.1password.1password"]

        let second = Preferences(defaults: defaults)
        #expect(second.ignoredBundleIDs == ["com.apple.keychainaccess", "com.1password.1password"])
    }

    @Test func historyLimitRoundTrips() {
        let defaults = makeDefaults()

        let first = Preferences(defaults: defaults)
        first.historyLimit = 200

        let second = Preferences(defaults: defaults)
        #expect(second.historyLimit == 200)
    }
}
