import AppKit
import QuickLateCore

@MainActor
final class AppPresenceController {
    static let shared = AppPresenceController()

    private init() {}

    func apply(_ settings: AppPresenceSettings, activate: Bool) {
        switch settings.activationPolicyIntent {
        case .accessory:
            NSApp.setActivationPolicy(.accessory)
        case .regular:
            NSApp.setActivationPolicy(.regular)
            if activate {
                NSApp.activate(ignoringOtherApps: true)
            }
        }
    }
}
