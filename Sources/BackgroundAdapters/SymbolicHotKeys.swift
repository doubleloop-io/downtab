public import SwitcherCore

/// The WindowServer's symbolic hot keys, the layer native ⌘Tab and ⌘` go through, by id.
public protocol SymbolicHotKeySwitch: Sendable {
    /// Nil when the state cannot be read.
    func isEnabled(_ id: Int32) -> Bool?
    /// Returns false when macOS refused the change or the private API is missing.
    @discardableResult func setEnabled(_ id: Int32, _ enabled: Bool) -> Bool
}

extension NativeShortcut {
    /// Ids read from AltTab (`docs/alttab-notes.md`); 27 is "Move focus to next window" in
    /// `com.apple.symbolichotkeys`.
    public var symbolicHotKeyIDs: [Int32] {
        switch self {
        case .commandTab: [1, 2]
        case .commandGrave: [27]
        }
    }
}

/// Private APIs: the change is global to the login session and outlives the process that made it.
public struct WindowServerSymbolicHotKeys: SymbolicHotKeySwitch {
    private typealias SetEnabled = @convention(c) (Int32, Bool) -> Int32
    private typealias IsEnabled = @convention(c) (Int32) -> Bool
    private typealias GetValue =
        @convention(c) (
            Int32, UnsafeMutablePointer<UInt16>, UnsafeMutablePointer<UInt16>, UnsafeMutablePointer<UInt64>
        ) -> Int32

    private static let setEnabledFunction = PrivateSymbol.resolve(
        "CGSSetSymbolicHotKeyEnabled", in: .skyLight, as: SetEnabled.self)
    private static let isEnabledFunction = PrivateSymbol.resolve(
        "CGSIsSymbolicHotKeyEnabled", in: .skyLight, as: IsEnabled.self)
    private static let getValueFunction = PrivateSymbol.resolve(
        "CGSGetSymbolicHotKeyValue", in: .skyLight, as: GetValue.self)

    public init() {}

    public func isEnabled(_ id: Int32) -> Bool? {
        Self.isEnabledFunction.map { $0(id) }
    }

    @discardableResult public func setEnabled(_ id: Int32, _ enabled: Bool) -> Bool {
        guard let setEnabled = Self.setEnabledFunction else { return false }
        return setEnabled(id, enabled) == 0
    }

    /// The combination macOS binds to the id, to check the ids still mean ⌘Tab and ⌘`. Nil when unreadable.
    public func binding(of id: Int32) -> (keyCode: Int, modifierFlags: UInt64)? {
        guard let getValue = Self.getValueFunction else { return nil }
        var character: UInt16 = 0
        var keyCode: UInt16 = 0
        // Wider than the API's flags, whose width is not documented: a narrower write leaves the rest zero.
        var modifierFlags: UInt64 = 0
        guard getValue(id, &character, &keyCode, &modifierFlags) == 0 else { return nil }
        return (Int(keyCode), modifierFlags)
    }
}
