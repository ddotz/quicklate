import Foundation

enum UpdateCheckState: Equatable {
    case idle
    case checking
    case updateAvailable(latestVersion: String, releaseURL: URL, packageURL: URL?)
    case downloading(latestVersion: String)
    case downloaded(latestVersion: String, fileURL: URL)
    case upToDate(latestVersion: String, releaseURL: URL)
    case failed(String)

    var releaseURL: URL? {
        switch self {
        case let .updateAvailable(_, releaseURL, _), let .upToDate(_, releaseURL):
            releaseURL
        case .idle, .checking, .downloading, .downloaded, .failed:
            nil
        }
    }

    var downloadedFileURL: URL? {
        switch self {
        case let .downloaded(_, fileURL):
            fileURL
        case .idle, .checking, .updateAvailable, .downloading, .upToDate, .failed:
            nil
        }
    }

    var isChecking: Bool {
        switch self {
        case .checking, .downloading:
            true
        case .idle, .updateAvailable, .downloaded, .upToDate, .failed:
            false
        }
    }
}
