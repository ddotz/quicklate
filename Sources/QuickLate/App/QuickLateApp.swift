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

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        if let appIcon = NSImage(named: "AppIcon") {
            NSApp.applicationIconImage = appIcon
        }
        let showDockIcon = UserDefaults.standard.bool(forKey: "showDockIcon")
        AppPresenceController.shared.apply(AppPresenceSettings(showDockIcon: showDockIcon), activate: showDockIcon)
    }
}
