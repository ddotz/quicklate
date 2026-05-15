import Testing
@testable import QuickLateCore

@Suite
struct AppleAssetDownloadPlanTests {
    @Test
    func combinedModelRoutesMissingTranslationThroughSwiftUITranslationTask() {
        let plan = AppleAssetDownloadPlan(
            model: .combined,
            speech: .installed,
            translation: .downloadRequired
        )

        #expect(plan.routes == [.swiftUITranslationTask])
        #expect(plan.modelsToMarkDownloading == [.combined, .translationOnly])
    }

    @Test
    func combinedModelDownloadsSpeechAndTranslationWithSeparateRoutes() {
        let plan = AppleAssetDownloadPlan(
            model: .combined,
            speech: .downloadRequired,
            translation: .downloadRequired
        )

        #expect(plan.routes == [.speechAssetInventory, .swiftUITranslationTask])
        #expect(plan.modelsToMarkDownloading == [.combined, .speechOnly, .translationOnly])
    }

    @Test
    func individualTranslationModelUsesSwiftUITranslationTask() {
        let plan = AppleAssetDownloadPlan(
            model: .translationOnly,
            speech: .installed,
            translation: .failed
        )

        #expect(plan.routes == [.swiftUITranslationTask])
        #expect(plan.modelsToMarkDownloading == [.combined, .translationOnly])
    }
}
