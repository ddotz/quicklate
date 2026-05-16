import Foundation
import Testing
@testable import QuickLateCore

@Suite
struct TranslationProviderModelTests {
    @Test
    func metadataDefaultsToNoTranslationAndTracksRefinedState() {
        let metadata = TranslationMetadata()
        #expect(metadata.phase == .none)
        #expect(metadata.provisionalText == nil)
        #expect(metadata.refinedText == nil)
        #expect(metadata.translatedSourceRevision == 0)

        let refinedAt = Date(timeIntervalSince1970: 42)
        let refined = TranslationMetadata(
            phase: .refined,
            provisionalText: "빠른 번역",
            refinedText: "문맥 보정 번역",
            translatedSourceRevision: 3,
            providerID: "foundation-models-refiner",
            refinedAt: refinedAt,
            failureReason: nil
        )

        #expect(refined.phase == .refined)
        #expect(refined.refinedText == "문맥 보정 번역")
        #expect(refined.refinedAt == refinedAt)
    }

    @Test
    func noOpRefinementProviderIsExplicitlyUnavailable() async {
        let provider = NoOpRefinementProvider()
        #expect(provider.id == "noop-refinement")
        #expect(provider.displayName == "Refinement Off")
        await #expect(throws: TranslationProviderError.self) {
            _ = try await provider.translate(
                TranslationProviderRequest(
                    sourceText: "Stable source text",
                    sourceLanguageID: "en-US",
                    targetLanguageID: "ko-KR",
                    previousSourceContext: "",
                    previousTargetContext: "",
                    glossary: [],
                    mode: .contextualRefinement
                )
            )
        }
    }

    @Test
    func traceEventDoesNotStoreRawTranscriptText() throws {
        let event = RealtimeTranslationTraceEvent(
            kind: .refinementRequested,
            providerID: "noop-refinement",
            lineID: UUID(),
            revision: 4,
            sourceCharacterCount: 27,
            latencyMilliseconds: nil,
            failureReason: nil
        )

        let data = try JSONEncoder().encode(event)
        let json = String(decoding: data, as: UTF8.self)

        #expect(json.contains("sourceCharacterCount"))
        #expect(!json.contains("Stable source text"))
    }
}
