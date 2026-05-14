import Foundation

enum FloatingCaptionLineCount: Int, CaseIterable, Identifiable {
    case two = 2
    case three = 3
    case four = 4
    case five = 5
    case six = 6

    var id: String { "\(rawValue)" }

    var title: String {
        AppText.lineCount(rawValue)
    }
}
