public enum TranslationLanguageControlMode: Equatable, Sendable {
    case manualSourceAndTarget
    case autoDetectTargetOnly

    public static func resolved(usesOpenAIRealtimeTranslation: Bool) -> TranslationLanguageControlMode {
        usesOpenAIRealtimeTranslation ? .autoDetectTargetOnly : .manualSourceAndTarget
    }
}

public struct QuickLateUIDensityMetrics: Equatable, Sendable {
    public let workspaceTitleFontSize: Double
    public let transcriptTitleFontSize: Double
    public let transcriptSubtitleFontSize: Double
    public let transcriptBodyFontSize: Double
    public let emptyStateFontSize: Double
    public let primaryButtonFontSize: Double
    public let languageChipFontSize: Double
    public let languageChipLineLimit: Int
    public let languageChipMinimumScaleFactor: Double
    public let topBarControlRowSpacing: Double
    public let workspaceColumnSpacing: Double

    public init(
        workspaceTitleFontSize: Double,
        transcriptTitleFontSize: Double,
        transcriptSubtitleFontSize: Double,
        transcriptBodyFontSize: Double,
        emptyStateFontSize: Double,
        primaryButtonFontSize: Double,
        languageChipFontSize: Double,
        languageChipLineLimit: Int,
        languageChipMinimumScaleFactor: Double,
        topBarControlRowSpacing: Double,
        workspaceColumnSpacing: Double
    ) {
        self.workspaceTitleFontSize = workspaceTitleFontSize
        self.transcriptTitleFontSize = transcriptTitleFontSize
        self.transcriptSubtitleFontSize = transcriptSubtitleFontSize
        self.transcriptBodyFontSize = transcriptBodyFontSize
        self.emptyStateFontSize = emptyStateFontSize
        self.primaryButtonFontSize = primaryButtonFontSize
        self.languageChipFontSize = languageChipFontSize
        self.languageChipLineLimit = languageChipLineLimit
        self.languageChipMinimumScaleFactor = languageChipMinimumScaleFactor
        self.topBarControlRowSpacing = topBarControlRowSpacing
        self.workspaceColumnSpacing = workspaceColumnSpacing
    }

    public static let comfortableDesktop = QuickLateUIDensityMetrics(
        workspaceTitleFontSize: 24,
        transcriptTitleFontSize: 18,
        transcriptSubtitleFontSize: 13,
        transcriptBodyFontSize: 20,
        emptyStateFontSize: 20,
        primaryButtonFontSize: 13,
        languageChipFontSize: 12,
        languageChipLineLimit: 1,
        languageChipMinimumScaleFactor: 0.82,
        topBarControlRowSpacing: 18,
        workspaceColumnSpacing: 32
    )
}
