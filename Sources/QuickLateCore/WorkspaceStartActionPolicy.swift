public enum WorkspaceStartRoute: String, Equatable, Sendable {
    case startCapture
    case downloadAssetsAndStart
    case openSystemSettings
    case changeLanguagePair
    case wait
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
}
