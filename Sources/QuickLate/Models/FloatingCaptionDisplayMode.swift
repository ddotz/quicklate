import Foundation

enum FloatingCaptionDisplayMode: String, CaseIterable, Identifiable {
    case original
    case originalAndTranslation
    case translation

    var id: String { rawValue }

    var title: String {
        switch self {
        case .original:
            AppText.originalOnly
        case .originalAndTranslation:
            AppText.originalAndTranslation
        case .translation:
            AppText.translationOnly
        }
    }

    var systemImage: String {
        switch self {
        case .original:
            "text.alignleft"
        case .originalAndTranslation:
            "rectangle.split.2x1"
        case .translation:
            "character.bubble"
        }
    }
}
