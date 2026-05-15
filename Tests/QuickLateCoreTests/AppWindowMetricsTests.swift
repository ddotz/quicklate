import Testing
@testable import QuickLateCore

@Suite
struct AppWindowMetricsTests {
    @Test
    func mainWindowDefaultSizeUsesVisibleScreenRatio() {
        let size = AppWindowMetrics.defaultMainWindowSize(
            visibleWidth: 1_920,
            visibleHeight: 1_050
        )

        #expect(size.width == 1_075)
        #expect(size.height == 714)
    }

    @Test
    func mainWindowDefaultSizeIsClampedForSmallAndLargeScreens() {
        let small = AppWindowMetrics.defaultMainWindowSize(
            visibleWidth: 1_280,
            visibleHeight: 720
        )
        let large = AppWindowMetrics.defaultMainWindowSize(
            visibleWidth: 3_456,
            visibleHeight: 2_160
        )

        #expect(small.width == AppWindowMetrics.minimumMainWindowWidth)
        #expect(small.height == AppWindowMetrics.minimumMainWindowHeight)
        #expect(large.width == AppWindowMetrics.maximumMainWindowWidth)
        #expect(large.height == AppWindowMetrics.maximumMainWindowHeight)
    }
}
