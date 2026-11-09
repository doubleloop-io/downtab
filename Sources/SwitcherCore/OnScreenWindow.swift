/// A level-0 window as the window server lists it, bounds in window-server coordinates.
public struct OnScreenWindow: Equatable, Sendable {
    public let owner: AppID
    public let bounds: ScreenRect
    public let alpha: Double

    public init(owner: AppID, bounds: ScreenRect, alpha: Double) {
        self.owner = owner
        self.bounds = bounds
        self.alpha = alpha
    }
}

extension [OnScreenWindow] {
    /// Read front to back: focusing a window raises it above the app's other windows.
    public func focusedWindow(of app: AppID) -> OnScreenWindow? {
        first { $0.owner == app && $0.isVisibleRealWindow }
    }
}

extension OnScreenWindow {
    fileprivate var isVisibleRealWindow: Bool {
        alpha > 0 && WindowSize(width: bounds.width, height: bounds.height).isLargeEnoughToBeReal
    }
}
