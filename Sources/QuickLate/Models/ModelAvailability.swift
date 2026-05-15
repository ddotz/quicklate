import Foundation
import QuickLateCore

enum ModelAvailabilityState {
    case checking
    case installed
    case downloadRequired
    case downloading
    case unsupported
    case unavailable
    case failed

    var title: String {
        switch self {
        case .checking:
            AppText.modelStatusChecking
        case .installed:
            AppText.modelStatusInstalled
        case .downloadRequired:
            AppText.modelStatusDownloadRequired
        case .downloading:
            AppText.modelStatusDownloading
        case .unsupported:
            AppText.modelStatusUnsupported
        case .unavailable:
            AppText.modelStatusUnavailable
        case .failed:
            AppText.modelStatusFailed
        }
    }

    var canDownload: Bool {
        assetInstallState.allowsDownloadRequest
    }

    private var assetInstallState: AssetInstallState {
        switch self {
        case .checking:
            .checking
        case .installed:
            .installed
        case .downloadRequired:
            .downloadRequired
        case .downloading:
            .downloading
        case .unsupported:
            .unsupported
        case .unavailable:
            .unavailable
        case .failed:
            .failed
        }
    }
}

struct ModelAvailability: Equatable {
    let state: ModelAvailabilityState
    let detail: String

    static func checking(for model: IntelligenceModel) -> ModelAvailability {
        ModelAvailability(state: .checking, detail: model.checkingDetail)
    }
}
