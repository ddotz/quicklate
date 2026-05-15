import Testing
@testable import QuickLateCore

@Suite
struct TranslationLanguageControlModeTests {
    @Test
    func appleModeUsesManualSourceAndTargetSelection() {
        let mode = TranslationLanguageControlMode.resolved(usesOpenAIRealtimeTranslation: false)

        #expect(mode == .manualSourceAndTarget)
    }

    @Test
    func gptRealtimeTranslationUsesAutoDetectTargetOnlySelection() {
        let mode = TranslationLanguageControlMode.resolved(usesOpenAIRealtimeTranslation: true)

        #expect(mode == .autoDetectTargetOnly)
    }
}
