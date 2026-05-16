import Foundation
import Observation
import QuickLateCore

@Observable
@MainActor
final class WorkspaceViewModel {
    let session: TranslationSessionStore

    init(session: TranslationSessionStore) {
        self.session = session
    }

    func requestStart() {
        if session.isRunning {
            session.stop()
        } else {
            session.requestStartFromWorkspace()
        }
    }
}
