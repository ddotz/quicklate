import Testing
@testable import QuickLateCore

@Suite
struct MenuBarPopoverShortcutTests {
    @Test
    func shortcutUsesRareGlobalChord() {
        #expect(MenuBarPopoverShortcut.keyEquivalent == "l")
        #expect(MenuBarPopoverShortcut.displayLabel == "⌃⌥⌘L")
    }
}
