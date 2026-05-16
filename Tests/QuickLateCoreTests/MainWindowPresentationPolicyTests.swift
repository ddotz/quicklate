import Testing
@testable import QuickLateCore

@Suite
struct MainWindowPresentationPolicyTests {
    @Test
    func opensDefaultSizedWindowWhenNoMainWindowExists() {
        let policy = MainWindowPresentationPolicy.action(hasVisibleMainWindow: false)

        #expect(policy == .openDefaultSizedWindow)
    }

    @Test
    func reusesExistingWindowInsteadOfOpeningAnotherOne() {
        let policy = MainWindowPresentationPolicy.action(hasVisibleMainWindow: true)

        #expect(policy == .bringExistingWindowToFront)
    }
}
