import AppKit
import Sparkle
import SwiftUI

/// Owns the Sparkle updater and exposes just the bits the UI needs.
///
/// `SPUStandardUpdaterController` starts the updater as soon as it is created,
/// which is what schedules the background check on the interval in Info.plist.
/// It is created once, by `AppDelegate`, and handed to every view that offers
/// a "Check for Updates" affordance.
@MainActor
@Observable
final class UpdaterController {
    /// Mirrors `SPUUpdater.canCheckForUpdates`, which goes false while a check
    /// is already in flight — the menu item and button bind to this so they
    /// disable themselves instead of stacking up duplicate checks.
    private(set) var canCheckForUpdates = false

    @ObservationIgnored private let controller: SPUStandardUpdaterController
    @ObservationIgnored private let userDriverDelegate = UpdatePresentationDelegate()
    @ObservationIgnored private var observation: NSKeyValueObservation?

    init() {
        controller = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: userDriverDelegate
        )
        observation = controller.updater.observe(\.canCheckForUpdates, options: [.initial, .new]) { updater, _ in
            let value = updater.canCheckForUpdates
            Task { @MainActor [weak self] in
                self?.canCheckForUpdates = value
            }
        }
    }

    func checkForUpdates() {
        controller.updater.checkForUpdates()
    }

    var automaticallyChecksForUpdates: Bool {
        get { controller.updater.automaticallyChecksForUpdates }
        set { controller.updater.automaticallyChecksForUpdates = newValue }
    }

    /// The date of the most recent successful check, for the "Last checked"
    /// line in Settings. Nil until the first check completes.
    var lastUpdateCheckDate: Date? {
        controller.updater.lastUpdateCheckDate
    }

    /// Marketing version and build number, as shown in Settings.
    var versionDescription: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "?"
        let build = info?["CFBundleVersion"] as? String ?? "?"
        return "Version \(short) (\(build))"
    }
}

/// Makes Sparkle's windows reachable in an accessory app.
///
/// CmdV is `LSUIElement`, so it has no Dock icon and its activation policy
/// keeps windows from taking focus — which is exactly right for the clipboard
/// panel and exactly wrong for an update dialog that appeared on its own. A
/// scheduled update would otherwise open behind whatever the user is doing,
/// with nothing to click to bring it forward. So for the duration of an update
/// session the app becomes a regular one, then goes back to being invisible.
private final class UpdatePresentationDelegate: NSObject, SPUStandardUserDriverDelegate {
    /// Deliberately false. "Gentle" reminders let Sparkle hold a scheduled
    /// update back until the app next becomes active, on the assumption that a
    /// normal app soon will. An accessory app with no Dock icon may go weeks
    /// without ever being the active app, so a gentle reminder is one that
    /// might never arrive — better to show the dialog and raise the app.
    var supportsGentleScheduledUpdateReminders: Bool { false }

    func standardUserDriverWillHandleShowingUpdate(
        _ handleShowingUpdate: Bool,
        forUpdate update: SUAppcastItem,
        state: SPUUserUpdateState
    ) {
        guard handleShowingUpdate else { return }
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: !state.userInitiated)
    }

    func standardUserDriverWillFinishUpdateSession() {
        NSApp.setActivationPolicy(.accessory)
    }
}
