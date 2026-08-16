import SwiftUI

struct SettingsView: View {
    @Bindable var preferences: Preferences
    let attemptHotkey: (KeyCombo) -> Bool
    let restartMonitoring: () -> Void

    var body: some View {
        TabView {
            GeneralSettingsView(preferences: preferences)
                .tabItem { Label("General", systemImage: "gearshape") }

            HotkeysSettingsView(preferences: preferences, attemptHotkey: attemptHotkey)
                .tabItem { Label("Hotkeys", systemImage: "keyboard") }

            HistorySettingsView(preferences: preferences, restartMonitoring: restartMonitoring)
                .tabItem { Label("History", systemImage: "clock") }

            PrivacySettingsView(preferences: preferences)
                .tabItem { Label("Privacy", systemImage: "lock") }
        }
        .frame(width: 460, height: 320)
    }
}
