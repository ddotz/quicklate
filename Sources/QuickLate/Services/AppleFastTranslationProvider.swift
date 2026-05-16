import Foundation
import QuickLateCore

actor AppleFastTranslationProvider: TranslationProvider {
    let id = "apple-fast-translation"
    let displayName = "Apple Translation"

    private let service: AppleTranslationService

    init(service: AppleTranslationService = AppleTranslationService()) {
        self.service = service
    }

    func prepare(sourceLanguageID: String, targetLanguageID: String) async throws {
        let source = try languageOption(for: sourceLanguageID)
        let target = try languageOption(for: targetLanguageID)
        try await service.prepare(source: source, target: target, model: .appleSystem)
    }

    func translate(_ request: TranslationProviderRequest) async throws -> TranslationProviderResponse {
        let startedAt = Date()
        let source = try languageOption(for: request.sourceLanguageID)
        let target = try languageOption(for: request.targetLanguageID)
        let translatedText = try await service.translate(
            request.sourceText,
            source: source,
            target: target,
            model: .appleSystem
        )
        return TranslationProviderResponse(
            translatedText: translatedText,
            providerID: id,
            latencyMilliseconds: Int(Date().timeIntervalSince(startedAt) * 1_000),
            isFinalQuality: request.mode == .contextualRefinement
        )
    }

    private func languageOption(for id: String) throws -> LanguageOption {
        guard let language = LanguageOption.supported.first(where: { $0.id == id }) else {
            throw TranslationProviderError.unavailable("Unsupported language: \(id)")
        }
        return language
    }
}
