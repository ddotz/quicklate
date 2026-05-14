public enum AppActivationPolicyIntent: Equatable, Sendable {
    case accessory
    case regular
}

public struct AppPresenceSettings: Equatable, Sendable {
    public var showDockIcon: Bool

    public init(showDockIcon: Bool) {
        self.showDockIcon = showDockIcon
    }

    public static let `default` = AppPresenceSettings(showDockIcon: false)

    public var activationPolicyIntent: AppActivationPolicyIntent {
        showDockIcon ? .regular : .accessory
    }
}
