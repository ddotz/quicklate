public enum TranslationLanguageControlMode: Equatable, Sendable {
    case manualSourceAndTarget
    case autoDetectTargetOnly

    public static func resolved(usesOpenAIRealtimeTranslation: Bool) -> TranslationLanguageControlMode {
        usesOpenAIRealtimeTranslation ? .autoDetectTargetOnly : .manualSourceAndTarget
    }
}
