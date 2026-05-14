import Testing
@testable import QuickLateCore

@Suite
struct AssetPreflightStateTests {
    @Test
    func installedSpeechAndMissingTranslationRequiresDownloadAndStart() {
        let state = AssetPreflightState(
            speech: .installed,
            translation: .downloadRequired,
            startIntent: .startAfterDownload
        )

        #expect(state.primaryAction == .downloadAndStart)
        #expect(state.blocksStart)
    }

    @Test
    func installedAssetsCanStartImmediately() {
        let state = AssetPreflightState(
            speech: .installed,
            translation: .installed,
            startIntent: .none
        )

        #expect(state.primaryAction == .start)
        #expect(!state.blocksStart)
    }

    @Test
    func unsupportedPairDoesNotOfferDownload() {
        let state = AssetPreflightState(
            speech: .installed,
            translation: .unsupported,
            startIntent: .none
        )

        #expect(state.primaryAction == .changeLanguagePair)
        #expect(state.blocksStart)
    }

    @Test
    func failedDownloadOffersRetryAndClearsStartIntent() {
        let state = AssetPreflightState(
            speech: .installed,
            translation: .failed,
            startIntent: .none
        )

        #expect(state.primaryAction == .retryDownload)
        #expect(state.startIntent == .none)
    }
}
