import AppKit
import QuickLateCore
import SwiftUI

@MainActor
enum MainWindowPresenter {
    private static var standaloneMainWindow: NSWindow?

    static func showMainWindow(openWindow: OpenWindowAction) {
        switch MainWindowPresentationPolicy.action(hasVisibleMainWindow: existingMainWindow() != nil) {
        case .bringExistingWindowToFront:
            if let window = existingMainWindow() {
                present(window)
            }
        case .openDefaultSizedWindow:
            openWindow(id: QuickLateWindowID.main)
            NSApp.activate(ignoringOtherApps: true)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                ensureMainWindowVisible()
            }
        }
    }

    static func ensureMainWindowVisible() {
        switch MainWindowPresentationPolicy.action(hasVisibleMainWindow: existingMainWindow() != nil) {
        case .bringExistingWindowToFront:
            if let window = existingMainWindow() {
                present(window)
            }
        case .openDefaultSizedWindow:
            let window = makeStandaloneMainWindow()
            standaloneMainWindow = window
            present(window)
        }
    }

    private static func existingMainWindow() -> NSWindow? {
        NSApp.windows.first { window in
            isMainWorkspaceWindow(window)
        }
    }

    private static func isMainWorkspaceWindow(_ window: NSWindow) -> Bool {
        if window.identifier?.rawValue == QuickLateWindowID.main {
            return true
        }
        return window.title == AppText.appName
            && window.frame.width >= CGFloat(AppWindowMetrics.minimumMainWindowWidth) * 0.75
            && window.frame.height >= CGFloat(AppWindowMetrics.minimumMainWindowHeight) * 0.75
    }

    private static func makeStandaloneMainWindow() -> NSWindow {
        let runtime = QuickLateRuntime.shared
        runtime.installMenuBarPanel()

        let frame = defaultFrame()
        let rootView = AnyView(
            ContentView(session: runtime.session)
                .preferredColorScheme(.light)
                .frame(
                    minWidth: CGFloat(AppWindowMetrics.minimumMainWindowWidth),
                    minHeight: CGFloat(AppWindowMetrics.minimumMainWindowHeight)
                )
                .background(MenuBarPanelInstaller(session: runtime.session, controller: runtime.menuBarPanelController))
        )
        let window = NSWindow(
            contentRect: frame,
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.identifier = NSUserInterfaceItemIdentifier(QuickLateWindowID.main)
        window.title = AppText.appName
        window.minSize = NSSize(
            width: CGFloat(AppWindowMetrics.minimumMainWindowWidth),
            height: CGFloat(AppWindowMetrics.minimumMainWindowHeight)
        )
        window.contentViewController = NSHostingController(rootView: rootView)
        window.isReleasedWhenClosed = false
        return window
    }

    private static func present(_ window: NSWindow) {
        applyDefaultFrameIfNeeded(to: window)
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
        E2ERuntimeReporter.report(
            "mainWindowPresented",
            fields: [
                "width": String(Int(window.frame.width.rounded())),
                "height": String(Int(window.frame.height.rounded())),
                "windowID": window.identifier?.rawValue ?? ""
            ]
        )
    }

    private static func applyDefaultFrameIfNeeded(to window: NSWindow) {
        let expected = defaultFrame()
        let sizeDelta = abs(window.frame.width - expected.width) + abs(window.frame.height - expected.height)
        if window.frame.width < CGFloat(AppWindowMetrics.minimumMainWindowWidth)
            || window.frame.height < CGFloat(AppWindowMetrics.minimumMainWindowHeight)
            || sizeDelta > 2
        {
            window.setFrame(expected, display: true)
        }
    }

    private static func defaultFrame() -> NSRect {
        let visibleFrame = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1_920, height: 1_050)
        let size = AppWindowMetrics.defaultMainWindowSize(
            visibleWidth: Int(visibleFrame.width.rounded()),
            visibleHeight: Int(visibleFrame.height.rounded())
        )
        return NSRect(
            x: visibleFrame.midX - CGFloat(size.width) / 2,
            y: visibleFrame.midY - CGFloat(size.height) / 2,
            width: CGFloat(size.width),
            height: CGFloat(size.height)
        )
    }
}
