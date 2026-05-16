import AppKit
import QuickLateCore
import SwiftUI

@main
struct QuickLateApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var session = QuickLateRuntime.shared.session
    @State private var menuBarPanelController = QuickLateRuntime.shared.menuBarPanelController

    private static let minimumMainWindowWidth = CGFloat(AppWindowMetrics.minimumMainWindowWidth)
    private static let minimumMainWindowHeight = CGFloat(AppWindowMetrics.minimumMainWindowHeight)

    private static var defaultMainWindowSize: (width: CGFloat, height: CGFloat) {
        let visibleFrame = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1_920, height: 1_050)
        let size = AppWindowMetrics.defaultMainWindowSize(
            visibleWidth: Int(visibleFrame.width.rounded()),
            visibleHeight: Int(visibleFrame.height.rounded())
        )
        return (width: CGFloat(size.width), height: CGFloat(size.height))
    }

    var body: some Scene {
        WindowGroup("QuickLate", id: QuickLateWindowID.main) {
            ContentView(session: session)
                .preferredColorScheme(.light)
                .frame(
                    minWidth: Self.minimumMainWindowWidth,
                    minHeight: Self.minimumMainWindowHeight
                )
                .background(MenuBarPanelInstaller(session: session, controller: menuBarPanelController))
                .onReceive(NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification)) { _ in
                    session.prepareForTermination()
                }
        }
        .defaultSize(width: Self.defaultMainWindowSize.width, height: Self.defaultMainWindowSize.height)
        .commands {
            CommandGroup(replacing: .newItem) {}
            CommandGroup(after: .appInfo) {
                Button(AppText.checkForUpdates) {
                    Task { @MainActor in
                        await session.checkForUpdates()
                    }
                }
                Button(AppText.showMenuBarPopover) {
                    menuBarPanelController.showPopoverFromShortcut()
                }
                .keyboardShortcut("l", modifiers: [.control, .option, .command])
            }
        }

        Window(AppText.floatingCaptions, id: QuickLateWindowID.floatingCaptions) {
            FloatingCaptionWindowView(session: session)
                .preferredColorScheme(.light)
        }
        .defaultSize(width: 720, height: 170)
        .windowStyle(.plain)
        .restorationBehavior(.disabled)

        Settings {
            SettingsView(session: session)
                .preferredColorScheme(.light)
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.appearance = NSAppearance(named: .aqua)
        if let appIcon = loadApplicationIcon() {
            NSApp.applicationIconImage = appIcon
        }
        let showDockIcon = UserDefaults.standard.bool(forKey: "showDockIcon")
        let settings = AppPresenceSettings(showDockIcon: showDockIcon)
        QuickLateRuntime.shared.installMenuBarPanel()
        AppPresenceController.shared.apply(settings, activate: showDockIcon)
        if settings.mainWindowLaunchBehavior == .showAtLaunch {
            scheduleDockLaunchMainWindowPresentation()
        }
        E2ERuntimeReporter.report(
            "appDidFinishLaunching",
            fields: [
                "showDockIcon": String(showDockIcon),
                "activationPolicy": settings.activationPolicyIntent.e2eName,
                "mainWindowLaunchBehavior": settings.mainWindowLaunchBehavior.e2eName
            ]
        )
        scheduleMenuBarOnlyLaunchCleanup(for: settings)
    }

    private func loadApplicationIcon() -> NSImage? {
        Bundle.main.url(forResource: "AppIcon", withExtension: "icns")
            .flatMap(NSImage.init(contentsOf:))
            ?? NSImage(named: "AppIcon")
    }

    private func scheduleMenuBarOnlyLaunchCleanup(for settings: AppPresenceSettings) {
        guard settings.mainWindowLaunchBehavior == .hideAtLaunch else { return }

        for delay in [0.10, 0.35, 0.90] {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                self.closeMainWindowsForMenuBarOnlyLaunch()
            }
        }
    }

    private func scheduleDockLaunchMainWindowPresentation() {
        for delay in [0.25, 0.70] {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                MainWindowPresenter.ensureMainWindowVisible()
            }
        }
    }

    private func closeMainWindowsForMenuBarOnlyLaunch() {
        for window in NSApp.windows where window.isVisible && isMainWorkspaceWindow(window) {
            window.close()
            E2ERuntimeReporter.report("mainWindowClosedForMenuBarOnly")
        }
    }

    private func isMainWorkspaceWindow(_ window: NSWindow) -> Bool {
        if window.identifier?.rawValue == QuickLateWindowID.main {
            return true
        }
        return window.title == AppText.appName
            && window.frame.width >= 800
            && window.frame.height >= 500
    }
}

private extension AppActivationPolicyIntent {
    var e2eName: String {
        switch self {
        case .accessory:
            "accessory"
        case .regular:
            "regular"
        }
    }
}

private extension MainWindowLaunchBehavior {
    var e2eName: String {
        switch self {
        case .hideAtLaunch:
            "hideAtLaunch"
        case .showAtLaunch:
            "showAtLaunch"
        }
    }
}
