import AppKit
import SwiftUI

struct PrivacySettingsView: View {
    @Bindable var preferences: Preferences

    private var sortedIgnoredApps: [String] {
        preferences.ignoredBundleIDs.sorted {
            displayName(for: $0).localizedCaseInsensitiveCompare(displayName(for: $1)) == .orderedAscending
        }
    }

    var body: some View {
        Form {
            Section("Never record copies from") {
                if preferences.ignoredBundleIDs.isEmpty {
                    Text("No apps ignored")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(sortedIgnoredApps, id: \.self) { bundleID in
                        HStack {
                            Text(displayName(for: bundleID))
                            Spacer()
                            Button {
                                preferences.ignoredBundleIDs.remove(bundleID)
                            } label: {
                                Image(systemName: "minus.circle.fill")
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                Button("Add App\u{2026}") { addApp() }
            }

            Section {
                LabeledContent("Password clips") {
                    Text("Automatically removed after 1 minute")
                        .foregroundStyle(.secondary)
                }
            } footer: {
                Text("Applies to clips flagged as passwords by their source app, like 1Password or Keychain Access.")
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }

    private func displayName(for bundleID: String) -> String {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else {
            return bundleID
        }
        return FileManager.default.displayName(atPath: url.path)
    }

    private func addApp() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.application]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false

        guard panel.runModal() == .OK, let url = panel.url,
              let bundleID = Bundle(url: url)?.bundleIdentifier else { return }
        preferences.ignoredBundleIDs.insert(bundleID)
    }
}
