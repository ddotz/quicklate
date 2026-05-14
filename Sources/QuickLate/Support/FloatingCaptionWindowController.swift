import AppKit
import SwiftUI

@MainActor
final class FloatingCaptionWindowController: NSObject, NSWindowDelegate {
    static let visibilityDidChangeNotification = Notification.Name("QuickLateFloatingCaptionVisibilityDidChange")

    static var isOpen: Bool {
        shared.window?.isVisible == true
    }

    static func toggle(session: TranslationSessionStore) {
        isOpen ? close() : open(session: session)
    }

    static func open(session: TranslationSessionStore) {
        shared.open(session: session)
    }

    static func close() {
        shared.close()
    }

    private static let shared = FloatingCaptionWindowController()

    private var window: NSPanel?

    private func open(session: TranslationSessionStore) {
        closeOrphanFloatingWindows()

        let panel = window ?? makeWindow(session: session)
        panel.contentView = NSHostingView(rootView: FloatingCaptionWindowView(session: session))
        configure(panel)
        if window == nil {
            positionForFirstOpen(panel)
        }
        window = panel
        panel.orderFrontRegardless()
        notifyVisibilityChanged()
    }

    private func close() {
        window?.close()
        window = nil
        notifyVisibilityChanged()
    }

    func windowWillClose(_ notification: Notification) {
        guard notification.object as? NSWindow === window else { return }
        window = nil
        Self.notifyVisibilityChanged()
    }

    private func makeWindow(session: TranslationSessionStore) -> NSPanel {
        let size = NSSize(width: 720, height: 170)
        let panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.contentView = NSHostingView(rootView: FloatingCaptionWindowView(session: session))
        panel.delegate = self
        panel.isReleasedWhenClosed = false
        return panel
    }

    private func configure(_ panel: NSPanel) {
        panel.identifier = NSUserInterfaceItemIdentifier(QuickLateWindowID.floatingCaptions)
        panel.title = AppText.floatingCaptions
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
        panel.isMovableByWindowBackground = true
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
    }

    private func positionForFirstOpen(_ panel: NSPanel) {
        guard let visibleFrame = NSScreen.main?.visibleFrame else { return }

        let frame = panel.frame
        let x = visibleFrame.midX - frame.width / 2
        let y = visibleFrame.minY + min(180, visibleFrame.height * 0.18)
        panel.setFrameOrigin(NSPoint(x: x, y: y))
    }

    private func closeOrphanFloatingWindows() {
        for candidate in NSApp.windows where candidate !== window {
            if candidate.identifier?.rawValue == QuickLateWindowID.floatingCaptions
                || candidate.title == AppText.floatingCaptions {
                candidate.close()
            }
        }
    }

    private func notifyVisibilityChanged() {
        Self.notifyVisibilityChanged()
    }

    private static func notifyVisibilityChanged() {
        NotificationCenter.default.post(name: visibilityDidChangeNotification, object: nil)
    }
}
