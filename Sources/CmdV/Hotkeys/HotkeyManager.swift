import Carbon.HIToolbox
import Foundation

/// Wraps Carbon's `RegisterEventHotKey` — chosen over a `CGEventTap` because it
/// needs no Accessibility permission and can't be broken by a revoked grant.
@MainActor
final class HotkeyManager {
    private var hotKeyRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?

    var onTrigger: (() -> Void)?

    private static let signature: OSType = {
        var value: OSType = 0
        for byte in "CmdV".utf8 { value = (value << 8) + OSType(byte) }
        return value
    }()

    private let hotKeyID = EventHotKeyID(signature: HotkeyManager.signature, id: 1)

    /// Registers `combo` as the global hotkey, replacing any previous registration.
    /// Returns `false` if the combo is already claimed by another app.
    @discardableResult
    func register(_ combo: KeyCombo) -> Bool {
        unregister()

        if eventHandler == nil {
            var eventType = EventTypeSpec(
                eventClass: OSType(kEventClassKeyboard),
                eventKind: OSType(kEventHotKeyPressed)
            )
            let selfPtr = Unmanaged.passUnretained(self).toOpaque()
            InstallEventHandler(
                GetApplicationEventTarget(),
                { _, _, userData -> OSStatus in
                    guard let userData else { return noErr }
                    let manager = Unmanaged<HotkeyManager>.fromOpaque(userData).takeUnretainedValue()
                    manager.onTrigger?()
                    return noErr
                },
                1,
                &eventType,
                selfPtr,
                &eventHandler
            )
        }

        let status = RegisterEventHotKey(
            combo.keyCode,
            combo.carbonModifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
        return status == noErr
    }

    func unregister() {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }
    }
}
