import Foundation
import QuickLateCore

#if canImport(FoundationModels)
import FoundationModels
#endif

actor FoundationModelsTranslationRefiner: TranslationProvider {
    let id = TranslationRefinementProviderID.foundationModels.providerRuntimeID
    let displayName = "Apple Foundation Model"

    func prepare(sourceLanguageID _: String, targetLanguageID _: String) async throws {
#if canImport(FoundationModels)
        let model = SystemLanguageModel.default
        guard model.isAvailable else {
            throw TranslationProviderError.unavailable(String(describing: model.availability))
        }
#else
        throw TranslationProviderError.unavailable("FoundationModels framework is unavailable in this build.")
#endif
    }

    func translate(_ request: TranslationProviderRequest) async throws -> TranslationProviderResponse {
        let startedAt = Date()
        try await prepare(sourceLanguageID: request.sourceLanguageID, targetLanguageID: request.targetLanguageID)

#if canImport(FoundationModels)
        let session = LanguageModelSession(instructions: Self.instructions)
        let response = try await session.respond(to: TranslationPromptBuilder.prompt(request: request))
        let translatedText = response.content.trimmingCharacters(in: .whitespacesAndNewlines)
        return TranslationProviderResponse(
            translatedText: translatedText,
            providerID: id,
            latencyMilliseconds: Int(Date().timeIntervalSince(startedAt) * 1_000),
            isFinalQuality: true
        )
#else
        throw TranslationProviderError.unavailable("FoundationModels framework is unavailable in this build.")
#endif
    }

#if canImport(FoundationModels)
    private static let instructions = """
    You are a realtime subtitle translation refiner. Return only the translated text for the current source. Do not explain. Do not summarize. Do not translate previous context. Preserve names, numbers, code, API names, and glossary hard rules.
    """
#endif
}
