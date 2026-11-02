public enum SwitcherState: Equatable, Sendable {
    case closed
}

public struct Switcher: Sendable {
    public private(set) var state: SwitcherState = .closed

    public init() {}
}
