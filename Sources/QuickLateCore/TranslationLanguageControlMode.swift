public enum TranslationLanguageControlMode: Equatable, Sendable {
    case manualSourceAndTarget
    case autoDetectTargetOnly

    public static func resolved(usesOpenAIRealtimeTranslation: Bool) -> TranslationLanguageControlMode {
        usesOpenAIRealtimeTranslation ? .autoDetectTargetOnly : .manualSourceAndTarget
    }
}

public struct AppWindowSize: Equatable, Sendable {
    public let width: Int
    public let height: Int

    public init(width: Int, height: Int) {
        self.width = width
        self.height = height
    }
}

public enum AppWindowMetrics {
    public static let widthRatio = 0.56
    public static let heightRatio = 0.68
    public static let minimumMainWindowWidth = 900
    public static let minimumMainWindowHeight = 560
    public static let maximumMainWindowWidth = 1_280
    public static let maximumMainWindowHeight = 820

    public static func defaultMainWindowSize(visibleWidth: Int, visibleHeight: Int) -> AppWindowSize {
        let scaledWidth = Int((Double(visibleWidth) * widthRatio).rounded())
        let scaledHeight = Int((Double(visibleHeight) * heightRatio).rounded())

        return AppWindowSize(
            width: clamp(scaledWidth, minimum: minimumMainWindowWidth, maximum: maximumMainWindowWidth),
            height: clamp(scaledHeight, minimum: minimumMainWindowHeight, maximum: maximumMainWindowHeight)
        )
    }

    private static func clamp(_ value: Int, minimum: Int, maximum: Int) -> Int {
        min(max(value, minimum), maximum)
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
