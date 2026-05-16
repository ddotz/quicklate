import Testing
@testable import QuickLateCore

@Suite
struct RealtimeLatencyPolicyTests {
    @Test
    func defaultsFavorSubSecondLiveCaptionUpdates() {
        #expect(RealtimeLatencyPolicy.largeTranscriptPresentationIntervalSeconds <= 0.18)
        #expect(RealtimeLatencyPolicy.defaultTranslationDebounceMilliseconds <= 25)
        #expect(RealtimeLatencyPolicy.initialTranslationBurstDebounceMilliseconds <= 35)
        #expect(RealtimeLatencyPolicy.maximumTranslationBurstHoldSeconds <= 0.25)
    }

    @Test
    func floatingCaptionDwellIsShortEnoughForRealtimeUse() {
        #expect(RealtimeLatencyPolicy.minimumFloatingCaptionDwellSeconds <= 0.8)
        #expect(RealtimeLatencyPolicy.maximumFloatingCaptionDwellSeconds <= 2.4)
        #expect(RealtimeLatencyPolicy.floatingCaptionCharactersPerSecond >= 44)
    }
}
