public struct SetupRailState: Equatable, Sendable {
    public var isExpanded: Bool
    public var isPinnedOpen: Bool
    public var preflight: AssetPreflightState

    public init(isExpanded: Bool, isPinnedOpen: Bool, preflight: AssetPreflightState) {
        self.isExpanded = isExpanded
        self.isPinnedOpen = isPinnedOpen
        self.preflight = preflight
    }

    public static let `default` = SetupRailState(
        isExpanded: false,
        isPinnedOpen: false,
        preflight: AssetPreflightState(speech: .checking, translation: .checking, startIntent: .none)
    )

    public var requiresAttention: Bool {
        switch preflight.primaryAction {
        case .downloadAndStart, .retryDownload, .changeLanguagePair, .openSystemSettings:
            true
        case .wait, .start:
            false
        }
    }

    public var shouldPeek: Bool {
        requiresAttention && !isExpanded && !isPinnedOpen
    }
}
