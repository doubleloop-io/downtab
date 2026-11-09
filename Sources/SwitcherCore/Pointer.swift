/// The item of the Switcher under the pointer.
public enum PointerTarget: Equatable, Sendable {
    /// The app at this index of the App row.
    case app(Int)
    /// The window at this index of the open Window list.
    case window(Int)
}

/// The direction of one scroll step, as the system delivers it: it already follows the natural scrolling setting.
public enum ScrollDirection: Equatable, Sendable {
    /// Towards the end of a list: the next window.
    case down
    /// Towards the start of a list: the previous window, then back to App level.
    case up
}

/// The mouse and the trackpad on the Switcher. The app sends only what the core cannot tell on its own: an item
/// entered by a moving pointer, so a still pointer never overrides a selection made with the keyboard.
public enum PointerEvent: Equatable, Sendable {
    /// The pointer moved onto an item it was not on before.
    case entered(PointerTarget)
    /// A click on an item.
    case clicked(PointerTarget)
    /// A click anywhere outside the Switcher and its Window list.
    case clickedOutside
    /// One scroll step over the Switcher or its Window list, on an item or between items.
    case scrolled(ScrollDirection, over: PointerTarget?)
}
