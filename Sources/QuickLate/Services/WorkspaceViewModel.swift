import Foundation
import Observation
import QuickLateCore

@Observable
@MainActor
final class WorkspaceViewModel {
    let session: TranslationSessionStore
    var isSetupRailExpanded = false
    var isSetupRailPinnedOpen = false

    init(session: TranslationSessionStore) {
        self.session = session
    }

    var setupRailState: SetupRailState {
        SetupRailState(
            isExpanded: isSetupRailExpanded,
            isPinnedOpen: isSetupRailPinnedOpen,
            preflight: session.applePreflightState
        )
    }

    func toggleSetupRail() {
        isSetupRailExpanded.toggle()
    }

    func requestStart() {
        if session.isRunning {
            session.stop()
        } else {
            session.requestStartFromWorkspace()
        }
    }
}
