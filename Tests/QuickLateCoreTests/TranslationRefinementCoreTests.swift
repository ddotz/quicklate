import Foundation
import Testing
@testable import QuickLateCore

@Suite
struct TranslationRefinementCoreTests {
    @Test
    func aggressivenessControlsStableDelayAndTimeout() {
        #expect(TranslationRefinementAggressiveness.conservative.policy.stableDelaySeconds > TranslationRefinementAggressiveness.balanced.policy.stableDelaySeconds)
        #expect(TranslationRefinementAggressiveness.quality.policy.stableDelaySeconds < TranslationRefinementAggressiveness.balanced.policy.stableDelaySeconds)
        #expect(TranslationRefinementAggressiveness.conservative.policy.timeoutSeconds == 1.2)
        #expect(TranslationRefinementAggressiveness.balanced.policy.timeoutSeconds == 1.8)
        #expect(TranslationRefinementAggressiveness.quality.policy.timeoutSeconds == 3.0)
    }

    @Test
    func contextBuilderKeepsRecentUnitsWithinCharacterBudgets() {
        let builder = TranslationContextBuilder(
            configuration: .init(
                recentUnitLimit: 3,
                maxSourceContextCharacters: 35,
                maxTargetContextCharacters: 28,
                maxGlossaryEntries: 2
            )
        )
        let now = Date(timeIntervalSince1970: 10)
        let units = [
            unit(source: "First source unit", target: "첫 번째 번역", createdAt: now),
            unit(source: "Second source unit", target: "두 번째 번역", createdAt: now.addingTimeInterval(1)),
            unit(source: "Third source unit", target: "세 번째 번역", createdAt: now.addingTimeInterval(2)),
            unit(source: "Fourth source unit", target: "네 번째 번역", createdAt: now.addingTimeInterval(3))
        ]
        let glossary = [
            glossary("latency", "레이턴시"),
            glossary("pipeline", "파이프라인"),
            glossary("model", "모델")
        ]

        let window = builder.build(
            previousUnits: units,
            currentSource: "Current source",
            glossaryEntries: glossary
        )

        #expect(window.currentSource == "Current source")
        #expect(window.previousSourceUnits == ["Third source unit", "Fourth source unit"])
        #expect(window.previousTargetUnits == ["두 번째 번역", "세 번째 번역", "네 번째 번역"])
        #expect(window.glossaryEntries.map(\.sourceTerm) == ["latency", "pipeline"])
    }

    @Test
    func promptBuilderUsesContextAsReferenceOnlyAndRequestsOnlyCurrentOutput() {
        let prompt = TranslationPromptBuilder.prompt(
            request: TranslationProviderRequest(
                sourceText: "This API reduces latency.",
                sourceLanguageID: "en-US",
                targetLanguageID: "ko-KR",
                previousSourceContext: "Earlier source context",
                previousTargetContext: "이전 번역 문맥",
                glossary: [glossary("API", "API", hard: true)],
                mode: .contextualRefinement
            )
        )

        #expect(prompt.contains("Translate only CURRENT_SOURCE"))
        #expect(prompt.contains("Previous source context is reference only"))
        #expect(prompt.contains("Do not explain"))
        #expect(prompt.contains("API => API (hard)"))
        #expect(prompt.contains("This API reduces latency."))
    }

    @Test
    func schedulerRejectsDuplicateLineRevisionAndAllowsCancel() async {
        let scheduler = ContextualRefinementScheduler()
        let lineID = UUID()
        let segment = StableSourceSegment(
            lineID: lineID,
            sourceText: "This is a stable source segment.",
            revision: 2,
            detectedAt: Date(timeIntervalSince1970: 20),
            reason: .unchangedForThreshold
        )

        #expect(await scheduler.enqueue(segment) == .accepted(segment))
        #expect(await scheduler.enqueue(segment) == .duplicate)
        await scheduler.cancel(lineID: lineID)
        #expect(await scheduler.enqueue(segment) == .accepted(segment))
    }

    @Test
    func benchmarkResultEncodesTraceWithoutRawAudio() throws {
        let scenario = BenchmarkScenario(
            id: "tech-talk-en-ko",
            audioFileURL: URL(fileURLWithPath: "/tmp/tech-talk.wav"),
            sourceLanguageID: "en-US",
            targetLanguageID: "ko-KR",
            referenceTranscript: nil,
            referenceTranslation: nil
        )
        let result = BenchmarkResult(
            scenarioID: scenario.id,
            providerID: "foundation-models-refiner",
            firstPartialLatencyMs: 120,
            firstTranslationLatencyMs: 240,
            refinementLatencyMs: 1_200,
            outputTranscript: "",
            outputTranslation: "",
            traceEvents: [
                RealtimeTranslationTraceEvent(
                    kind: .refinementAccepted,
                    providerID: "foundation-models-refiner",
                    sourceCharacterCount: 42,
                    latencyMilliseconds: 1_200
                )
            ]
        )

        let data = try JSONEncoder().encode(result)
        let json = String(decoding: data, as: UTF8.self)

        #expect(json.contains("tech-talk-en-ko"))
        #expect(!json.contains("rawAudio"))
    }

    private func unit(source: String, target: String, createdAt: Date) -> TranslationUnit {
        TranslationUnit(
            lineID: UUID(),
            sourceText: source,
            sourceRevision: 1,
            sourceLanguageID: "en-US",
            targetLanguageID: "ko-KR",
            provisionalTranslation: target,
            refinedTranslation: nil,
            phase: .provisional,
            createdAt: createdAt
        )
    }

    private func glossary(_ source: String, _ target: String, hard: Bool = false) -> TranslationGlossaryEntry {
        TranslationGlossaryEntry(
            sourceTerm: source,
            targetTerm: target,
            isHardRule: hard,
            createdAt: Date(timeIntervalSince1970: 0),
            updatedAt: Date(timeIntervalSince1970: 0)
        )
    }
}
