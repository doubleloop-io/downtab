/// Where the Switcher opens. The display is chosen at opening and kept while the Switcher stays open.
public enum SwitcherPlacement: CaseIterable, Sendable {
    case pointerDisplay
    case menuBarDisplay
    case focusedWindowDisplay
}

public enum SwitcherDisplay {
    /// `displays` are AppKit frames, menu bar display first; `focusedWindow` is in window-server coordinates.
    /// Returns nil only when there is no display.
    public static func index(
        for placement: SwitcherPlacement, displays: [ScreenRect], pointer: ScreenPoint, focusedWindow: ScreenRect?
    ) -> Int? {
        guard !displays.isEmpty else { return nil }
        switch placement {
        case .pointerDisplay:
            return displays.firstIndex { $0.containsPointer(pointer) } ?? menuBarDisplay
        case .focusedWindowDisplay:
            guard let focusedWindow else { return menuBarDisplay }
            return displayHoldingMostOf(focusedWindow.flipped(around: displays[menuBarDisplay]), in: displays)
        case .menuBarDisplay:
            return menuBarDisplay
        }
    }

    /// AppKit lists the display with the menu bar first.
    private static let menuBarDisplay = 0

    private static func displayHoldingMostOf(_ window: ScreenRect, in displays: [ScreenRect]) -> Int {
        let areas = displays.map { $0.overlapArea(with: window) }
        guard let largest = areas.max(), largest > 0, let index = areas.firstIndex(of: largest) else {
            return menuBarDisplay
        }
        return index
    }
}
