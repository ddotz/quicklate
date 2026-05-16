import AppKit
import Carbon
import QuickLateCore

@MainActor
final class MenuBarPopoverHotKey {
    private static let signature = fourCharacterCode("QLPO")
    private static let hotKeyID = UInt32(1)

    private var eventHandler: EventHandlerRef?
    private var hotKey: EventHotKeyRef?
    private var action: (() -> Void)?

    func register(action: @escaping () -> Void) {
        unregister()
        self.action = action

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        let userData = Unmanaged.passUnretained(self).toOpaque()
        let handlerStatus = InstallEventHandler(
            GetApplicationEventTarget(),
            { _, _, userData in
                guard let userData else { return noErr }
                let hotKey = Unmanaged<MenuBarPopoverHotKey>
                    .fromOpaque(userData)
                    .takeUnretainedValue()
                Task { @MainActor in
                    hotKey.trigger()
                }
                return noErr
            },
            1,
            &eventType,
            userData,
            &eventHandler
        )
        guard handlerStatus == noErr else {
            self.action = nil
            E2ERuntimeReporter.report(
                "menuBarHotKeyRegistrationFailed",
                fields: ["stage": "eventHandler", "status": String(handlerStatus)]
            )
            return
        }

        let hotKeyID = EventHotKeyID(
            signature: Self.signature,
            id: Self.hotKeyID
        )
        let modifierFlags = UInt32(controlKey | optionKey | cmdKey)
        let hotKeyStatus = RegisterEventHotKey(
            UInt32(kVK_ANSI_L),
            modifierFlags,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKey
        )

        if hotKeyStatus == noErr {
            E2ERuntimeReporter.report(
                "menuBarHotKeyRegistered",
                fields: ["shortcut": MenuBarPopoverShortcut.displayLabel]
            )
        } else {
            E2ERuntimeReporter.report(
                "menuBarHotKeyRegistrationFailed",
                fields: ["stage": "hotKey", "status": String(hotKeyStatus)]
            )
            unregister()
        }
    }

    func unregister() {
        if let hotKey {
            UnregisterEventHotKey(hotKey)
            self.hotKey = nil
        }
        if let eventHandler {
            RemoveEventHandler(eventHandler)
            self.eventHandler = nil
        }
        action = nil
    }

    private func trigger() {
        action?()
    }

    private static func fourCharacterCode(_ string: String) -> OSType {
        var result: OSType = 0
        for scalar in string.unicodeScalars.prefix(4) {
            result = (result << 8) + OSType(scalar.value)
        }
        return result
    }
}
