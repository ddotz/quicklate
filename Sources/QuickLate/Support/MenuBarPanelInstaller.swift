import SwiftUI

struct MenuBarPanelInstaller: NSViewRepresentable {
    let session: TranslationSessionStore
    let controller: MenuBarPanelController

    func makeNSView(context _: Context) -> NSView {
        NSView(frame: .zero)
    }

    func updateNSView(_: NSView, context _: Context) {
        controller.install(session: session)
    }
}
