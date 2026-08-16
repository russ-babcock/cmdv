import SwiftUI

struct GeneralSettingsView: View {
    @Bindable var preferences: Preferences

    var body: some View {
        Form {
            Section {
                Toggle("Launch at startup", isOn: Binding(
                    get: { preferences.launchAtLogin },
                    set: {
                        preferences.launchAtLogin = $0
                        LoginItem.setEnabled($0)
                    }
                ))

                Toggle("Show menu bar icon", isOn: $preferences.showMenuBarIcon)
            }

            Section {
                Picker("Appearance", selection: Binding(
                    get: { preferences.appearance },
                    set: {
                        preferences.appearance = $0
                        AppAppearance.apply($0)
                    }
                )) {
                    ForEach(Preferences.AppearanceMode.allCases, id: \.self) { mode in
                        Text(mode.label).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
            }

            Section {
                Picker("Open clipboard window at", selection: $preferences.windowPositionMode) {
                    Text("Mouse cursor").tag(Preferences.WindowPositionMode.cursor)
                    Text("Center of screen").tag(Preferences.WindowPositionMode.centered)
                }
            }
        }
        .formStyle(.grouped)
    }
}
