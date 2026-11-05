public enum SwitcherEvent: Equatable, Sendable {
    /// A key pressed with the modifiers held at that moment. Closed, only the App or Window shortcut opens; open,
    /// only their keys act, pressed with the Modifier. ⇧ added moves the selection back.
    case keyPressed(Shortcut)
    /// The modifiers now held. Open, releasing any key of the Modifier confirms.
    case modifiersChanged(held: Set<ShortcutModifier>)
    case enterPressed
    case escapePressed
    case downPressed
    case upPressed
    case leftPressed
    case rightPressed
    /// `Switcher.showDelay` after opening, unless it already closed.
    case showDelayElapsed
}

/// What closing the Switcher asks the app to do.
public enum FinalEffect: Equatable, Sendable {
    /// Cancel: focus stays where it was.
    case noChange
    /// Confirm at App level: bring the app forward like the native switcher. With a window, also bring that window
    /// to the front: activation alone can leave macOS in the Current Space, the window moves it to the app's Space.
    case activateApp(AppID, frontingWindow: WindowID? = nil)
    /// Confirm at Window level: only that window comes forward, the app's other windows stay where they are.
    case bringWindowToFront(WindowID, of: AppID, restoring: WindowRestoration = [])
}

/// What must be undone before the window can come forward.
public struct WindowRestoration: OptionSet, Sendable {
    public let rawValue: Int

    public init(rawValue: Int) {
        self.rawValue = rawValue
    }

    public static let unminimize = WindowRestoration(rawValue: 1 << 0)
    /// Unhides the whole app: hiding is per app, not per window.
    public static let unhide = WindowRestoration(rawValue: 1 << 1)
}

/// What confirming the window will do besides bringing it forward.
public enum WindowLabel: Equatable, Sendable {
    /// Restored from the Dock.
    case minimized
    /// Its app is hidden: confirming unhides the app.
    case hidden
}

public struct WindowListEntry: Equatable, Sendable {
    public let id: WindowID
    public let title: String
    public let labels: [WindowLabel]

    var restoration: WindowRestoration {
        var restoration: WindowRestoration = []
        if labels.contains(.minimized) { restoration.insert(.unminimize) }
        if labels.contains(.hidden) { restoration.insert(.unhide) }
        return restoration
    }
}

public struct AppRowEntry: Equatable, Sendable {
    public let id: AppID
    public let name: String
    /// Front to back.
    public let windows: [WindowListEntry]
    /// Nil unless the app has windows only in other Spaces.
    let windowToFrontOnActivation: WindowID?

    /// Nil when the app has fewer than 2 windows: only an app with something to descend into gets a badge.
    public var windowCountBadge: Int? { windows.count >= 2 ? windows.count : nil }
}

public enum SelectionLevel: Equatable, Sendable {
    case app
    /// The index of the selected window in the selected app's Window list.
    case window(Int)
    /// Window level reached with `←` / `→` on an app with fewer than 2 windows: the app is selected without a
    /// Window list, and the next `←` / `→` opens the list of the app it lands on.
    case windowWithoutList
}

public struct DisplayedState: Equatable, Sendable {
    public let appRow: [AppRowEntry]
    public private(set) var selectedIndex: Int
    public private(set) var level: SelectionLevel
    /// False until the show delay elapses: a quick press confirms without the Switcher ever appearing. Hidden, it
    /// still takes every key, so none reaches the Frontmost app.
    public private(set) var isVisible = false
    /// Fixed at opening, like the App row.
    let frontmostApp: AppID?
    /// The modifiers of the shortcut that opened the Switcher.
    public let modifier: Set<ShortcutModifier>

    init(
        appRow: [AppRowEntry], frontmostApp: AppID?, modifier: Set<ShortcutModifier>, selectedIndex: Int = 0,
        level: SelectionLevel = .app
    ) {
        self.appRow = appRow
        self.frontmostApp = frontmostApp
        self.modifier = modifier
        self.selectedIndex = selectedIndex
        self.level = level
    }

    public var selectedEntry: AppRowEntry { appRow[selectedIndex] }

    var confirmation: FinalEffect {
        switch level {
        case .app, .windowWithoutList:
            .activateApp(selectedEntry.id, frontingWindow: selectedEntry.windowToFrontOnActivation)
        case .window(let index):
            .bringWindowToFront(
                selectedEntry.windows[index].id, of: selectedEntry.id,
                restoring: selectedEntry.windows[index].restoration)
        }
    }

    /// Wraps around at both ends of the App row, back at App level.
    func movingSelection(by step: Int) -> DisplayedState {
        let count = appRow.count
        var moved = self
        moved.selectedIndex = ((selectedIndex + step) % count + count) % count
        moved.level = .app
        return moved
    }

    /// The Window shortcut key: at App level opens the Window list like `↓`, with ⇧ on its last window; in the
    /// list, wraps around at both ends.
    func movingWindowSelection(by step: Int) -> DisplayedState {
        let count = selectedEntry.windows.count
        switch level {
        case .app:
            guard let opening = windowListOpening else { return self }
            return at(step < 0 ? .window(count - 1) : opening)
        case .window(let index):
            return at(.window(((index + step) % count + count) % count))
        case .windowWithoutList:
            return self
        }
    }

    /// `←` / `→`: at Window level, change app and stay at Window level, opening its Window list if it has one.
    func movingAcrossApps(by step: Int) -> DisplayedState {
        let moved = movingSelection(by: step)
        switch level {
        case .app: return moved
        case .window, .windowWithoutList: return moved.at(moved.windowListOpening ?? .windowWithoutList)
        }
    }

    /// `↓`: opens the Window list of an app with at least 2 windows, then walks it down to the last window.
    func movingDown() -> DisplayedState {
        switch level {
        case .app:
            return windowListOpening.map(at) ?? self
        case .window(let index):
            return at(.window(min(index + 1, selectedEntry.windows.count - 1)))
        case .windowWithoutList:
            return self
        }
    }

    /// `↑`: walks the Window list up; from the first window, back to App level.
    func movingUp() -> DisplayedState {
        switch level {
        case .app: self
        case .window(0), .windowWithoutList: at(.app)
        case .window(let index): at(.window(index - 1))
        }
    }

    /// Nil when the selected app has fewer than 2 windows, so there is no Window list to open.
    private var windowListOpening: SelectionLevel? {
        guard selectedEntry.windowCountBadge != nil else { return nil }
        // The Frontmost app's first window is the one being left.
        return .window(selectedEntry.id == frontmostApp ? 1 : 0)
    }

    func shown() -> DisplayedState {
        var shown = self
        shown.isVisible = true
        return shown
    }

    private func at(_ level: SelectionLevel) -> DisplayedState {
        var moved = self
        moved.level = level
        return moved
    }
}

public enum SwitcherState: Equatable, Sendable {
    case closed
    case open(DisplayedState)
}

public struct Switcher: Sendable {
    /// Like the native switcher: long enough that a quick press never flashes the Switcher. To tune with use.
    public static let showDelay = Duration.milliseconds(100)

    public private(set) var state: SwitcherState = .closed
    public var shortcuts: Shortcuts

    public init(shortcuts: Shortcuts = .defaults) {
        self.shortcuts = shortcuts
    }

    /// Returns the final effect when the event closes the Switcher, nil while it stays open or closed.
    @discardableResult
    public mutating func handle(_ event: SwitcherEvent, desktop: DesktopSnapshot) -> FinalEffect? {
        switch event {
        case .modifiersChanged(let held):
            guard case .open(let displayed) = state, !displayed.modifier.isSubset(of: held) else { return nil }
            return confirm()
        case .enterPressed:
            return confirm()
        case .escapePressed:
            return cancel()
        case .keyPressed(let combination):
            press(combination, desktop: desktop)
        case .downPressed, .upPressed, .leftPressed, .rightPressed:
            updateWhileOpen { Self.moving($0, by: event) }
        case .showDelayElapsed:
            updateWhileOpen { $0.shown() }
        }
        return nil
    }

    private mutating func press(_ combination: Shortcut, desktop: DesktopSnapshot) {
        guard let press = shortcutPress(of: combination) else { return }
        let step = press.isReversed ? -1 : 1
        switch press.slot {
        case .app: moveSelection(by: step, desktop: desktop, modifier: press.modifier)
        case .window: moveWindowSelection(by: step, desktop: desktop, modifier: press.modifier)
        }
    }

    /// Nil unless the combination is, with or without ⇧, a shortcut when closed, or a shortcut key with the
    /// Modifier when open.
    private func shortcutPress(of combination: Shortcut) -> ShortcutPress? {
        let modifier = combination.modifiers.subtracting([.shift])
        let unshifted = Shortcut(keyCode: combination.keyCode, modifiers: modifier)
        let exactSlot = ShortcutSlot.allCases.first { shortcuts[$0] == unshifted }
        let slot: ShortcutSlot?
        switch state {
        case .closed:
            slot = exactSlot
        case .open(let displayed):
            guard modifier == displayed.modifier else { return nil }
            // When both shortcuts share a key, the one held exactly wins.
            slot = exactSlot ?? ShortcutSlot.allCases.first { shortcuts[$0].keyCode == combination.keyCode }
        }
        return slot.map {
            ShortcutPress(slot: $0, isReversed: combination.modifiers.contains(.shift), modifier: modifier)
        }
    }

    private mutating func confirm() -> FinalEffect? {
        guard case .open(let displayed) = state else { return nil }
        state = .closed
        return displayed.confirmation
    }

    private mutating func cancel() -> FinalEffect? {
        guard state != .closed else { return nil }
        state = .closed
        return .noChange
    }

    private mutating func updateWhileOpen(_ move: (DisplayedState) -> DisplayedState) {
        if case .open(let displayed) = state { state = .open(move(displayed)) }
    }

    private static func moving(_ displayed: DisplayedState, by arrow: SwitcherEvent) -> DisplayedState {
        switch arrow {
        case .downPressed: displayed.movingDown()
        case .upPressed: displayed.movingUp()
        case .leftPressed: displayed.movingAcrossApps(by: -1)
        case .rightPressed: displayed.movingAcrossApps(by: 1)
        default: displayed
        }
    }

    private mutating func moveSelection(by step: Int, desktop: DesktopSnapshot, modifier: Set<ShortcutModifier>) {
        switch state {
        case .open(let displayed):
            state = .open(displayed.movingSelection(by: step))
        case .closed:
            // The App row is fixed at opening: it never moves while the Switcher is open.
            let appRow = desktop.appRow()
            guard !appRow.isEmpty else { return }
            // Opening starts on the app being left, so the first step lands on the previous app.
            let opening = DisplayedState(appRow: appRow, frontmostApp: desktop.frontmostApp, modifier: modifier)
            state = .open(opening.movingSelection(by: step))
        }
    }

    private mutating func moveWindowSelection(
        by step: Int, desktop: DesktopSnapshot, modifier: Set<ShortcutModifier>
    ) {
        switch state {
        case .open(let displayed):
            state = .open(displayed.movingWindowSelection(by: step))
        case .closed:
            let appRow = desktop.appRow()
            guard let frontmostIndex = appRow.firstIndex(where: { $0.id == desktop.frontmostApp }),
                appRow[frontmostIndex].windowCountBadge != nil
            else { return }
            // Like App row opening: starts on the window being left, so the first step lands on the next one.
            let opening = DisplayedState(
                appRow: appRow, frontmostApp: desktop.frontmostApp, modifier: modifier, selectedIndex: frontmostIndex,
                level: .window(0))
            state = .open(opening.movingWindowSelection(by: step))
        }
    }
}

private struct ShortcutPress {
    let slot: ShortcutSlot
    /// Held with ⇧: moves the selection back.
    let isReversed: Bool
    let modifier: Set<ShortcutModifier>
}
