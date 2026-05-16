import Foundation
import QuickLateCore

actor MLXLocalLLMTranslationProvider: TranslationProvider {
    let id = TranslationRefinementProviderID.mlxLocalLLM.providerRuntimeID
    let displayName = "Local LLM"

    func prepare(sourceLanguageID _: String, targetLanguageID _: String) async throws {
        throw TranslationProviderError.unavailable("MLX local LLM refinement is not bundled in this build.")
    }

    func translate(_ request: TranslationProviderRequest) async throws -> TranslationProviderResponse {
        throw TranslationProviderError.unavailable("MLX local LLM refinement is not bundled in this build.")
    }
}
