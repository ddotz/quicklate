import AppKit
import QuickLateCore
import SwiftUI

@main
struct QuickLateApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var session = TranslationSessionStore()
    @State private var menuBarPanelController = MenuBarPanelController()

    var body: some Scene {
        WindowGroup("QuickLate", id: QuickLateWindowID.main) {
            ContentView(session: session)
                .frame(minWidth: 900, minHeight: 560)
                .background(MenuBarPanelInstaller(session: session, controller: menuBarPanelController))
                .onReceive(NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification)) { _ in
                    session.prepareForTermination()
                }
        }
        .commands {
            CommandGroup(replacing: .newItem) {}
        }

        Window(AppText.floatingCaptions, id: QuickLateWindowID.floatingCaptions) {
            FloatingCaptionWindowView(session: session)
        }
        .defaultSize(width: 720, height: 170)
        .windowStyle(.plain)
        .restorationBehavior(.disabled)

        Settings {
            SettingsView(session: session)
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        if let appIcon = loadApplicationIcon() {
            NSApp.applicationIconImage = appIcon
        }
        let showDockIcon = UserDefaults.standard.bool(forKey: "showDockIcon")
        let settings = AppPresenceSettings(showDockIcon: showDockIcon)
        AppPresenceController.shared.apply(settings, activate: showDockIcon)
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
