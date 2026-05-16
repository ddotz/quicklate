public enum WorkspaceStartRoute: String, Equatable, Sendable {
    case startCapture
    case downloadAssetsAndStart
    case openSystemSettings
    case changeLanguagePair
    case wait
}

public enum WorkspaceStartFailureKind: Equatable, Sendable {
    case permissionRequired
    case other
}

public enum WorkspaceStartFailureRecoveryRoute: String, Equatable, Sendable {
    case requestPermissionsAgain
    case showError
}

public enum WorkspaceStartActionPolicy {
    public static func route(for primaryAction: AssetPrimaryAction) -> WorkspaceStartRoute {
        switch primaryAction {
        case .start:
            .startCapture
        case .downloadAndStart, .retryDownload:
            .downloadAssetsAndStart
        case .openSystemSettings:
            .openSystemSettings
        case .changeLanguagePair:
            .changeLanguagePair
        case .wait:
            .wait
        }
    }

    public static func continuationRouteAfterAvailabilityRefresh(for state: AssetPreflightState) -> WorkspaceStartRoute? {
        guard state.startIntent == .startAfterDownload else { return nil }

        switch state.primaryAction {
        case .start:
            return .startCapture
        case .downloadAndStart, .retryDownload:
            return .downloadAssetsAndStart
        case .wait, .openSystemSettings, .changeLanguagePair:
            return nil
        }
    }

    public static func recoveryRoute(for failureKind: WorkspaceStartFailureKind) -> WorkspaceStartFailureRecoveryRoute {
        switch failureKind {
        case .permissionRequired:
            .requestPermissionsAgain
        case .other:
            .showError
        }
    }
}
