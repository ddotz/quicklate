import AppKit
import QuickLateCore
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
        popover.contentSize = NSSize(width: 360, height: 520)
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

    func showPopoverFromShortcut() {
        showPopover(activatesApp: true)
    }

    @objc
    private func togglePopover(_ sender: Any?) {
        if popover.isShown {
            popover.performClose(sender)
        } else {
            showPopover(activatesApp: false)
        }

        refreshButtonAppearance()
    }

    private func showPopover(activatesApp: Bool) {
        guard let button = statusItem?.button else {
            return
        }

        if activatesApp {
            NSApp.activate()
        }
        if !popover.isShown {
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
        button.toolTip = "\(AppText.menuBarTitle) · \(MenuBarPopoverShortcut.displayLabel)"
        E2ERuntimeReporter.report("statusItemInstalled")
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

        statusItem?.length = 30
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
        if let template = templateResourceImage() {
            return template
        }

        return fallbackTemplateImage()
    }

    private static func templateResourceImage() -> NSImage? {
        guard let source = Bundle.main.url(forResource: "MenuBarIcon", withExtension: "png")
            .flatMap(NSImage.init(contentsOf:))
            ?? NSImage(named: "MenuBarIcon")
        else {
            return nil
        }

        let image = NSImage(size: NSSize(width: 20, height: 20))
        image.lockFocus()
        source.draw(
            in: NSRect(x: 0, y: 0, width: 20, height: 20),
            from: .zero,
            operation: .sourceOver,
            fraction: 1,
            respectFlipped: true,
            hints: [.interpolation: NSImageInterpolation.high]
        )
        image.unlockFocus()
        image.isTemplate = true
        return image
    }

    private static func fallbackTemplateImage() -> NSImage {
        let image = NSImage(size: NSSize(width: 20, height: 20))
        image.lockFocus()
        NSColor.black.setStroke()
        let ring = NSBezierPath(ovalIn: NSRect(x: 2.7, y: 3.0, width: 13.0, height: 13.0))
        ring.lineWidth = 3.2
        ring.lineCapStyle = .round
        ring.lineJoinStyle = .round
        ring.stroke()
        let tail = NSBezierPath()
        tail.lineWidth = 3.2
        tail.lineCapStyle = .round
        tail.lineJoinStyle = .round
        tail.move(to: NSPoint(x: 12.0, y: 7.0))
        tail.line(to: NSPoint(x: 17.2, y: 3.0))
        tail.stroke()
        image.unlockFocus()
        image.isTemplate = true
        return image
    }
}
