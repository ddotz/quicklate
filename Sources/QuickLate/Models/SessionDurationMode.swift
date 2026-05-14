import Foundation

enum SessionDurationMode: String, CaseIterable, Identifiable {
    case standard
    case thirtyMinutesOrMore

    var id: String { rawValue }

    var title: String {
        switch self {
        case .standard:
            AppText.sessionLengthStandard
        case .thirtyMinutesOrMore:
            AppText.sessionLengthThirtyMinutesOrMore
        }
    }

    var detail: String {
        switch self {
        case .standard:
            AppText.sessionLengthStandardDescription
        case .thirtyMinutesOrMore:
            AppText.sessionLengthThirtyMinutesOrMoreDescription
        }
    }
}
