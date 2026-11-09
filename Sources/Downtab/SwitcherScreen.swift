import AppKit
import BackgroundAdapters
import SwitcherCore

enum SwitcherScreen {
    static func forOpening(frontmostApp: AppID?) -> NSScreen? {
        let screens = NSScreen.screens
        let placement = SettingsStore().switcherPlacement()
        let pointer = NSEvent.mouseLocation
        let index = SwitcherDisplay.index(
            for: placement,
            displays: screens.map { ScreenRect($0.frame) },
            pointer: ScreenPoint(x: Double(pointer.x), y: Double(pointer.y)),
            focusedWindow: placement == .focusedWindowDisplay ? focusedWindowBounds(of: frontmostApp) : nil)
        return index.map { screens[$0] }
    }

    // Read only for this placement: the other placements never query the window server.
    private static func focusedWindowBounds(of app: AppID?) -> ScreenRect? {
        guard let app else { return nil }
        return OnScreenWindowOrder.windowsFrontToBack().focusedWindow(of: app)?.bounds
    }
}
