import AppKit
import SwiftUI

@MainActor
enum SettingsWindowPresenter {
    private static var standaloneSettingsWindow: NSWindow?

    static func showSettingsWindow() {
        if let window = existingSettingsWindow() {
            present(window)
            return
        }

        let window = makeStandaloneSettingsWindow()
        standaloneSettingsWindow = window
        present(window)
    }

    private static func existingSettingsWindow() -> NSWindow? {
        NSApp.windows.first { window in
            window.title == "QuickLate Settings"
                || window.title == AppText.settings
                || window.title.localizedCaseInsensitiveContains("settings")
        }
    }

    private static func makeStandaloneSettingsWindow() -> NSWindow {
        let runtime = QuickLateRuntime.shared
        runtime.installMenuBarPanel()

        let visibleFrame = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1_920, height: 1_050)
        let size = NSSize(width: 620, height: min(720, max(680, visibleFrame.height * 0.72)))
        let frame = NSRect(
            x: visibleFrame.midX - size.width / 2,
            y: visibleFrame.midY - size.height / 2,
            width: size.width,
            height: size.height
        )
        let window = NSWindow(
            contentRect: frame,
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "QuickLate Settings"
        window.minSize = NSSize(width: 620, height: 680)
        window.contentViewController = NSHostingController(
            rootView: SettingsView(session: runtime.session)
                .preferredColorScheme(.light)
        )
        window.isReleasedWhenClosed = false
        return window
    }

    private static func present(_ window: NSWindow) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
        E2ERuntimeReporter.report("settingsWindowPresented")
    }
}
