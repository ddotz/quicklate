public enum MainWindowPresentationAction: Equatable, Sendable {
    case openDefaultSizedWindow
    case bringExistingWindowToFront
}

public enum MainWindowPresentationPolicy {
    public static func action(hasVisibleMainWindow: Bool) -> MainWindowPresentationAction {
        hasVisibleMainWindow ? .bringExistingWindowToFront : .openDefaultSizedWindow
    }
}
