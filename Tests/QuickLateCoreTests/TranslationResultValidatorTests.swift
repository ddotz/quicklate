import Foundation
import Testing
@testable import QuickLateCore

@Suite
struct TranslationResultValidatorTests {
    @Test
    func acceptsReasonableKoreanSubtitle() {
        let result = TranslationResultValidator.validate(
            refinedText: "API 지연 시간을 줄이는 파이프라인입니다.",
            sourceText: "This is a pipeline that reduces API latency.",
            previousTargetContext: "앞에서는 모델 구조를 설명했습니다.",
            targetLanguageID: "ko-KR",
            glossary: [
                TranslationGlossaryEntry(
                    sourceTerm: "API",
                    targetTerm: "API",
                    isHardRule: true,
                    createdAt: Date(timeIntervalSince1970: 0),
                    updatedAt: Date(timeIntervalSince1970: 0)
                )
            ]
        )

        #expect(result == .accepted)
    }

    @Test
    func rejectsEmptyAndPromptLeakOutputs() {
        #expect(TranslationResultValidator.validate(
            refinedText: "   ",
            sourceText: "Translate this sentence.",
            previousTargetContext: "",
            targetLanguageID: "ko-KR",
            glossary: []
        ) == .rejected(reason: .empty))

        #expect(TranslationResultValidator.validate(
            refinedText: "번역: 이 문장을 번역합니다.",
            sourceText: "Translate this sentence.",
            previousTargetContext: "",
            targetLanguageID: "ko-KR",
            glossary: []
        ) == .rejected(reason: .containsPromptLeak))
    }

    @Test
    func rejectsTooLongSourceCopyAndDuplicateContext() {
        #expect(TranslationResultValidator.validate(
            refinedText: String(repeating: "너무 긴 출력 ", count: 80),
            sourceText: "Short sentence.",
            previousTargetContext: "",
            targetLanguageID: "ko-KR",
            glossary: []
        ) == .rejected(reason: .tooLong))

        #expect(TranslationResultValidator.validate(
            refinedText: "This sentence should not be copied verbatim.",
            sourceText: "This sentence should not be copied verbatim.",
            previousTargetContext: "",
            targetLanguageID: "ko-KR",
            glossary: []
        ) == .rejected(reason: .repeatsSourceVerbatim))

        #expect(TranslationResultValidator.validate(
            refinedText: "이전 문맥 전체를 그대로 반복합니다.",
            sourceText: "Now translate only the current sentence.",
            previousTargetContext: "이전 문맥 전체를 그대로 반복합니다.",
            targetLanguageID: "ko-KR",
            glossary: []
        ) == .rejected(reason: .duplicateOfPreviousContext))
    }

    @Test
    func rejectsLikelyWrongLanguageAndHardGlossaryViolation() {
        #expect(TranslationResultValidator.validate(
            refinedText: "This output is still mostly English even though Korean is requested.",
            sourceText: "This output is still mostly English even though Korean is requested.",
            previousTargetContext: "",
            targetLanguageID: "ko-KR",
            glossary: []
        ) == .rejected(reason: .repeatsSourceVerbatim))

        #expect(TranslationResultValidator.validate(
            refinedText: "모델의 지연 시간을 줄입니다.",
            sourceText: "We reduce API latency.",
            previousTargetContext: "",
            targetLanguageID: "ko-KR",
            glossary: [
                TranslationGlossaryEntry(
                    sourceTerm: "API",
                    targetTerm: "API",
                    isHardRule: true,
                    createdAt: Date(timeIntervalSince1970: 0),
                    updatedAt: Date(timeIntervalSince1970: 0)
                )
            ]
        ) == .rejected(reason: .glossaryViolation))
    }
}
