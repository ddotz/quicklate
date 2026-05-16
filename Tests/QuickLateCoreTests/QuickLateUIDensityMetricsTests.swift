import Testing
@testable import QuickLateCore

@Suite
struct QuickLateUIDensityMetricsTests {
    @Test
    func comfortableDesktopTypographyAvoidsOversizedText() {
        let metrics = QuickLateUIDensityMetrics.comfortableDesktop

        #expect(metrics.workspaceTitleFontSize <= 24)
        #expect(metrics.transcriptBodyFontSize <= 21)
        #expect(metrics.emptyStateFontSize <= 20)
        #expect(metrics.primaryButtonFontSize <= 13)
    }

    @Test
    func compactControlsPreferSingleLineKoreanLabels() {
        let metrics = QuickLateUIDensityMetrics.comfortableDesktop

        #expect(metrics.languageChipLineLimit == 1)
        #expect(metrics.languageChipMinimumScaleFactor >= 0.8)
        #expect(metrics.topBarControlRowSpacing >= 16)
        #expect(metrics.workspaceColumnSpacing >= 28)
    }

    @Test
    func updateControlsStayCompactAndReadable() {
        let metrics = QuickLateUIDensityMetrics.comfortableDesktop

        #expect(metrics.menuBarUpdateButtonFontSize <= 11)
        #expect(metrics.settingsVersionFooterFontSize <= 12)
        #expect(metrics.menuBarUpdateButtonFontSize < metrics.primaryButtonFontSize)
    }

    @Test
    func glossaryHardRuleToggleHasRoomForKoreanLabel() {
        let metrics = QuickLateUIDensityMetrics.comfortableDesktop

        #expect(metrics.glossaryHardRuleToggleMinWidth >= 116)
        #expect(metrics.glossaryHardRuleToggleFontSize <= 12)
    }
}
