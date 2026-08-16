import SwiftUI

struct HotkeysSettingsView: View {
    @Bindable var preferences: Preferences
    let attemptHotkey: (KeyCombo) -> Bool

    @State private var conflictMessage: String?

    var body: some View {
        Form {
            Section {
                LabeledContent("Open clipboard window") {
                    HotkeyRecorder(combo: preferences.hotkey, onCapture: handleCapture)
                        .frame(width: 160, height: 24)
                }
            } footer: {
                if let conflictMessage {
                    Text(conflictMessage)
                        .foregroundStyle(.red)
                }
            }

            Section {
                Picker("Number/letter key activation", selection: $preferences.pinActivation) {
                    Text("Bare key (1\u{2013}9, A\u{2013}Z)").tag(Preferences.PinActivationMode.bareKey)
                    Text("Control + key").tag(Preferences.PinActivationMode.controlKey)
                }
            } footer: {
                Text(pinActivationHint)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }

    private var pinActivationHint: String {
        switch preferences.pinActivation {
        case .bareKey:
            "Press a number or letter directly while the list has focus to paste that clip. \u{2318}F focuses search."
        case .controlKey:
            "Hold Control and press a number or letter from anywhere in the window to paste that clip."
        }
    }

    private func handleCapture(_ newCombo: KeyCombo) {
        if attemptHotkey(newCombo) {
            preferences.hotkey = newCombo
            conflictMessage = nil
        } else {
            _ = attemptHotkey(preferences.hotkey)
            conflictMessage = "That shortcut is already in use."
        }
    }
}
