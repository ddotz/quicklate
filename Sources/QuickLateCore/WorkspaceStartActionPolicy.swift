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

    public static func recoveryRoute(for failureKind: WorkspaceStartFailureKind) -> WorkspaceStartFailureRecoveryRoute {
        switch failureKind {
        case .permissionRequired:
            .requestPermissionsAgain
        case .other:
            .showError
        }
    }
}
