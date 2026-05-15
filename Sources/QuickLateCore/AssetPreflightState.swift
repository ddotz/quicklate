public enum AssetInstallState: Equatable, Sendable {
    case checking
    case installed
    case downloadRequired
    case downloading
    case failed
    case unsupported
    case unavailable

    public var allowsDownloadRequest: Bool {
        switch self {
        case .downloadRequired, .failed:
            true
        case .checking, .installed, .downloading, .unsupported, .unavailable:
            false
        }
    }
}

public enum AssetStartIntent: Equatable, Sendable {
    case none
    case startAfterDownload
}

public enum AssetPrimaryAction: Equatable, Sendable {
    case wait
    case start
    case downloadAndStart
    case retryDownload
    case changeLanguagePair
    case openSystemSettings
}

public struct AssetPreflightState: Equatable, Sendable {
    public var speech: AssetInstallState
    public var translation: AssetInstallState
    public var startIntent: AssetStartIntent

    public init(
        speech: AssetInstallState,
        translation: AssetInstallState,
        startIntent: AssetStartIntent
    ) {
        self.speech = speech
        self.translation = translation
        self.startIntent = startIntent
    }

    public var blocksStart: Bool {
        primaryAction != .start
    }

    public var primaryAction: AssetPrimaryAction {
        if speech == .checking || translation == .checking || speech == .downloading || translation == .downloading {
            return .wait
        }
        if speech == .installed && translation == .installed {
            return .start
        }
        if speech == .failed || translation == .failed {
            return .retryDownload
        }
        if speech == .unsupported || translation == .unsupported {
            return .changeLanguagePair
        }
        if speech == .unavailable || translation == .unavailable {
            return .openSystemSettings
        }
        return .downloadAndStart
    }
}
