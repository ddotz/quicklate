import Testing
@testable import QuickLateCore

@Suite
struct SetupRailStateTests {
    @Test
    func railIsCollapsedByDefault() {
        let state = SetupRailState.default

        #expect(state.isExpanded == false)
        #expect(state.isPinnedOpen == false)
    }

    @Test
    func blockingPreflightShowsAttention() {
        let state = SetupRailState(
            isExpanded: false,
            isPinnedOpen: false,
            preflight: AssetPreflightState(
                speech: .installed,
                translation: .downloadRequired,
                startIntent: .none
            )
        )

        #expect(state.requiresAttention)
        #expect(state.shouldPeek)
    }

    @Test
    func installedAssetsDoNotPeekWhenCollapsed() {
        let state = SetupRailState(
            isExpanded: false,
            isPinnedOpen: false,
            preflight: AssetPreflightState(
                speech: .installed,
                translation: .installed,
                startIntent: .none
            )
        )

        #expect(!state.requiresAttention)
        #expect(!state.shouldPeek)
    }
}
