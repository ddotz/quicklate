import Foundation

enum UpdateCheckState: Equatable {
    case idle
    case checking
    case updateAvailable(latestVersion: String, releaseURL: URL, packageURL: URL?)
    case downloading(latestVersion: String)
    case installing(latestVersion: String)
    case upToDate(latestVersion: String, releaseURL: URL)
    case failed(String)

    var releaseURL: URL? {
        switch self {
        case let .updateAvailable(_, releaseURL, _), let .upToDate(_, releaseURL):
            releaseURL
        case .idle, .checking, .downloading, .installing, .failed:
            nil
        }
    }

    var isChecking: Bool {
        switch self {
        case .checking, .downloading, .installing:
            true
        case .idle, .updateAvailable, .upToDate, .failed:
            false
        }
    }
}
