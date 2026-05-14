import Foundation
import QuickLateCore

@MainActor
final class AssetDownloadCoordinator {
    private(set) var startIntent: AssetStartIntent = .none

    func state(from availability: ModelAvailability) -> AssetInstallState {
        switch availability.state {
        case .checking:
            .checking
        case .installed:
            .installed
        case .downloadRequired:
            .downloadRequired
        case .downloading:
            .downloading
        case .failed:
            .failed
        case .unsupported:
            .unsupported
        case .unavailable:
            .unavailable
        }
    }

    func rememberStartAfterDownload() {
        startIntent = .startAfterDownload
    }

    func clearStartIntent() {
        startIntent = .none
    }
}
