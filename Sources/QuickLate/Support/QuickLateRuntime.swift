import Foundation

@MainActor
final class QuickLateRuntime {
    static let shared = QuickLateRuntime()

    let session: TranslationSessionStore
    let menuBarPanelController: MenuBarPanelController
    private let menuBarPopoverHotKey = MenuBarPopoverHotKey()

    private init() {
        session = TranslationSessionStore()
        menuBarPanelController = MenuBarPanelController()
    }

    func installMenuBarPanel() {
        menuBarPanelController.install(session: session)
        menuBarPopoverHotKey.register { [menuBarPanelController] in
            menuBarPanelController.showPopoverFromShortcut()
        }
    }
}
