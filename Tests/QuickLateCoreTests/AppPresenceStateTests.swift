import Testing
@testable import QuickLateCore

@Suite
struct AppPresenceStateTests {
    @Test
    func dockIconIsHiddenByDefault() {
        let settings = AppPresenceSettings.default

        #expect(settings.showDockIcon == false)
        #expect(settings.activationPolicyIntent == .accessory)
    }

    @Test
    func showingDockIconUsesRegularActivationPolicy() {
        let settings = AppPresenceSettings(showDockIcon: true)

        #expect(settings.activationPolicyIntent == .regular)
    }

    @Test
    func hidingDockIconUsesAccessoryActivationPolicy() {
        let settings = AppPresenceSettings(showDockIcon: false)

        #expect(settings.activationPolicyIntent == .accessory)
    }
}
