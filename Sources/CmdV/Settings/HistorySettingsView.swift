import SwiftUI

struct HistorySettingsView: View {
    @Bindable var preferences: Preferences
    let restartMonitoring: () -> Void

    var body: some View {
        Form {
            Section {
                Stepper(
                    "Keep \(preferences.historyLimit) clips",
                    value: $preferences.historyLimit,
                    in: 10...500,
                    step: 10
                )
            } footer: {
                Text("Favorited and locked clips are always kept, even past this limit.")
                    .foregroundStyle(.secondary)
            }

            Section {
                Picker("Check clipboard every", selection: Binding(
                    get: { preferences.pollInterval },
                    set: {
                        preferences.pollInterval = $0
                        restartMonitoring()
                    }
                )) {
                    Text("0.25 seconds").tag(0.25)
                    Text("0.5 seconds").tag(0.5)
                    Text("1 second").tag(1.0)
                }
            }
        }
        .formStyle(.grouped)
    }
}
