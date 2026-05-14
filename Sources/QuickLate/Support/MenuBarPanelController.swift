import AppKit
import SwiftUI

@MainActor
final class MenuBarPanelController: NSObject, NSPopoverDelegate {
    private let popover = NSPopover()
    private let hostingController = NSHostingController(rootView: AnyView(EmptyView()))
    private var statusItem: NSStatusItem?
    private weak var session: TranslationSessionStore?
    private var lastWasActive = false
    private let appearanceChangedNotification = Notification.Name("AppleInterfaceThemeChangedNotification")

    override init() {
        super.init()
        popover.animates = true
        popover.behavior = .transient
        popover.contentSize = NSSize(width: 360, height: 430)
        popover.contentViewController = hostingController
        popover.delegate = self
        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(systemAppearanceDidChange(_:)),
            name: appearanceChangedNotification,
            object: nil
        )
    }

    deinit {
        DistributedNotificationCenter.default().removeObserver(self)
    }

    func install(session: TranslationSessionStore) {
        ensureStatusItem()
        update(session: session)
    }

    func update(session: TranslationSessionStore) {
        self.session = session
        hostingController.rootView = AnyView(MenuBarStatusView(session: session))
        updateStatusButton(using: session)
    }

    func popoverDidShow(_ notification: Notification) {
        refreshButtonAppearance()
    }

    func popoverDidClose(_ notification: Notification) {
        refreshButtonAppearance()
    }

    @objc
    private func togglePopover(_ sender: Any?) {
        guard let button = statusItem?.button else {
            return
        }

        if popover.isShown {
            popover.performClose(sender)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }

        refreshButtonAppearance()
    }

    @objc
    private func systemAppearanceDidChange(_ notification: Notification) {
        refreshButtonAppearance()
    }

    private func ensureStatusItem() {
        guard statusItem == nil else {
            return
        }

        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.isVisible = true
        statusItem = item

        guard let button = item.button else {
            return
        }

        button.target = self
        button.action = #selector(togglePopover(_:))
        button.sendAction(on: [.leftMouseDown])
        button.imagePosition = .imageOnly
        button.imageScaling = .scaleProportionallyDown
        button.toolTip = AppText.menuBarTitle
    }

    private func refreshButtonAppearance() {
        guard let session else {
            return
        }

        updateStatusButton(using: session)
    }

    private func updateStatusButton(using session: TranslationSessionStore) {
        refreshStatusItemPositionIfNeeded(session: session)
        guard let button = statusItem?.button else {
            return
        }

        applyMenuBarAppearance(to: button)
        let title = menuBarTitle(for: session)

        statusItem?.length = 28
        button.attributedTitle = NSAttributedString(string: "")
        button.image = MenuBarMiniAppIconRenderer.image()
        button.toolTip = session.statusMessage
        button.setAccessibilityTitle(title)
    }

    private func applyMenuBarAppearance(to button: NSStatusBarButton) {
        button.appearance = isSystemDarkMode ? NSAppearance(named: .darkAqua) : nil
    }

    private var isSystemDarkMode: Bool {
        UserDefaults.standard.string(forKey: "AppleInterfaceStyle") == "Dark"
    }

    private func refreshStatusItemPositionIfNeeded(session: TranslationSessionStore) {
        let isActive = session.isRunning || session.isPaused
        guard isActive != lastWasActive else {
            return
        }

        lastWasActive = isActive
        guard let statusItem else {
            return
        }

        NSStatusBar.system.removeStatusItem(statusItem)
        self.statusItem = nil
        ensureStatusItem()
    }

    private func menuBarTitle(for session: TranslationSessionStore) -> String {
        if session.isPaused {
            return AppText.menuBarPausedTitle
        }
        if session.isRunning {
            return AppText.menuBarRunningTitle
        }
        return AppText.menuBarTitle
    }

}

@MainActor
private enum MenuBarMiniAppIconRenderer {
    static func image() -> NSImage {
        if let appIcon = appIconImage() {
            return appIcon
        }

        return fallbackImage()
    }

    private static func appIconImage() -> NSImage? {
        guard let source = Bundle.main.url(forResource: "AppIcon", withExtension: "icns")
            .flatMap(NSImage.init(contentsOf:))
            ?? NSImage(named: "AppIcon")
        else {
            return nil
        }

        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size)
        image.lockFocus()
        source.draw(
            in: NSRect(origin: .zero, size: size),
            from: .zero,
            operation: .sourceOver,
            fraction: 1.0,
            respectFlipped: true,
            hints: [.interpolation: NSImageInterpolation.high]
        )
        image.unlockFocus()
        image.isTemplate = false
        return image
    }

    private static func fallbackImage() -> NSImage {
        let image = NSImage(size: NSSize(width: 18, height: 18))
        image.lockFocus()

        let iconRect = NSRect(x: 1, y: 1, width: 16, height: 16)
        let background = NSBezierPath(roundedRect: iconRect, xRadius: 4.5, yRadius: 4.5)
        NSColor.white.setFill()
        background.fill()
        NSColor.black.withAlphaComponent(0.18).setStroke()
        background.lineWidth = 0.75
        background.stroke()

        NSColor.black.setFill()
        drawPixelSoundBars(in: iconRect)
        drawPixelABC(in: iconRect)

        image.unlockFocus()
        image.isTemplate = false
        return image
    }

    private static func drawPixelSoundBars(in iconRect: NSRect) {
        let pixel: CGFloat = 1.35
        let baseline = iconRect.minY + 8.6
        let centerX = iconRect.midX

        fillPixelRect(x: centerX - 5.1, y: baseline - 2.0, width: pixel, height: 4.0)
        fillPixelRect(x: centerX - 2.5, y: baseline - 4.0, width: pixel, height: 6.0)
        fillPixelRect(x: centerX, y: baseline - 5.5, width: pixel, height: 7.5)
        fillPixelRect(x: centerX + 2.5, y: baseline - 4.0, width: pixel, height: 6.0)
        fillPixelRect(x: centerX + 5.1, y: baseline - 2.0, width: pixel, height: 4.0)
    }

    private static func drawPixelABC(in iconRect: NSRect) {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(ofSize: 5.8, weight: .black),
            .foregroundColor: NSColor.black
        ]
        let text = "abc" as NSString
        let textSize = text.size(withAttributes: attributes)
        let origin = NSPoint(
            x: iconRect.midX - textSize.width / 2,
            y: iconRect.maxY - textSize.height - 2.4
        )
        text.draw(at: origin, withAttributes: attributes)
    }

    private static func fillPixelRect(x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat) {
        NSBezierPath(rect: NSRect(x: round(x), y: round(y), width: round(width), height: round(height))).fill()
    }
}
