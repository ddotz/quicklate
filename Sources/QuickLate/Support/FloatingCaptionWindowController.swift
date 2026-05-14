import AppKit
import SwiftUI

private enum FloatingCaptionFrameKey {
    static let x = "floatingCaptionFrameX"
    static let y = "floatingCaptionFrameY"
    static let width = "floatingCaptionFrameWidth"
    static let height = "floatingCaptionFrameHeight"
}

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
        if window == nil, !restoreSavedFrame(panel) {
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
        saveFrame()
        window = nil
        Self.notifyVisibilityChanged()
    }

    func windowDidMove(_ notification: Notification) {
        guard notification.object as? NSWindow === window else { return }
        saveFrame()
    }

    func windowDidResize(_ notification: Notification) {
        guard notification.object as? NSWindow === window else { return }
        saveFrame()
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

    @discardableResult
    private func positionForFirstOpen(_ panel: NSPanel) -> Bool {
        guard let visibleFrame = NSScreen.main?.visibleFrame else { return false }

        let frame = panel.frame
        let x = visibleFrame.midX - frame.width / 2
        let y = visibleFrame.minY + min(180, visibleFrame.height * 0.18)
        panel.setFrameOrigin(NSPoint(x: x, y: y))
        return true
    }

    private func saveFrame() {
        guard let frame = window?.frame else { return }
        let defaults = UserDefaults.standard
        defaults.set(frame.origin.x, forKey: FloatingCaptionFrameKey.x)
        defaults.set(frame.origin.y, forKey: FloatingCaptionFrameKey.y)
        defaults.set(frame.size.width, forKey: FloatingCaptionFrameKey.width)
        defaults.set(frame.size.height, forKey: FloatingCaptionFrameKey.height)
    }

    @discardableResult
    private func restoreSavedFrame(_ panel: NSPanel) -> Bool {
        let defaults = UserDefaults.standard
        guard defaults.object(forKey: FloatingCaptionFrameKey.x) != nil,
              defaults.object(forKey: FloatingCaptionFrameKey.y) != nil,
              defaults.object(forKey: FloatingCaptionFrameKey.width) != nil,
              defaults.object(forKey: FloatingCaptionFrameKey.height) != nil else {
            return false
        }

        let frame = NSRect(
            x: defaults.double(forKey: FloatingCaptionFrameKey.x),
            y: defaults.double(forKey: FloatingCaptionFrameKey.y),
            width: max(360, defaults.double(forKey: FloatingCaptionFrameKey.width)),
            height: max(110, defaults.double(forKey: FloatingCaptionFrameKey.height))
        )
        panel.setFrame(frame, display: false)
        return true
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
