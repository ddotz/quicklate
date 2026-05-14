import QuickLateCore
import Testing

@Suite
struct SaleReadinessStateTests {
    @Test
    func menuBarDefaultHidesMainWindowAtLaunch() {
        let settings = AppPresenceSettings.default

        #expect(settings.activationPolicyIntent == .accessory)
        #expect(settings.mainWindowLaunchBehavior == .hideAtLaunch)
    }

    @Test
    func dockOptInShowsMainWindowAtLaunch() {
        let settings = AppPresenceSettings(showDockIcon: true)

        #expect(settings.activationPolicyIntent == .regular)
        #expect(settings.mainWindowLaunchBehavior == .showAtLaunch)
    }

    @Test
    func readinessLogRoundTripsJsonLines() throws {
        let event = E2EReadinessEvent(
            name: "statusItemInstalled",
            fields: ["app": "QuickLate", "mode": "menuBar"]
        )

        let line = try E2EReadinessLog.encodeLine(event)
        let events = E2EReadinessLog.decodeLines(line + "\nnot json\n")

        #expect(events == [event])
        #expect(E2EReadinessLog.containsEvent(named: "statusItemInstalled", in: line))
        #expect(!E2EReadinessLog.containsEvent(named: "missing", in: line))
    }
}
