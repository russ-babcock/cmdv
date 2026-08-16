import Foundation
import ServiceManagement

/// Wraps `SMAppService.mainApp` for the "Launch at startup" toggle. Registration
/// is tied to this exact app bundle's path — moving `CmdV.app` after registering
/// once means re-toggling the setting.
enum LoginItem {
    static var isRegistered: Bool {
        SMAppService.mainApp.status == .enabled
    }

    static func setEnabled(_ enabled: Bool) {
        do {
            let isEnabled = SMAppService.mainApp.status == .enabled
            if enabled, !isEnabled {
                try SMAppService.mainApp.register()
            } else if !enabled, isEnabled {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            NSLog("CmdV: failed to \(enabled ? "register" : "unregister") login item: \(error)")
        }
    }
}
