import Foundation

enum UpdateCheckState: Equatable {
    case idle
    case checking
    case updateAvailable(latestVersion: String, releaseURL: URL)
    case upToDate(latestVersion: String, releaseURL: URL)
    case failed(String)

    var releaseURL: URL? {
        switch self {
        case let .updateAvailable(_, releaseURL), let .upToDate(_, releaseURL):
            releaseURL
        case .idle, .checking, .failed:
            nil
        }
    }

    var isChecking: Bool {
        if case .checking = self {
            return true
        }
        return false
    }
}
