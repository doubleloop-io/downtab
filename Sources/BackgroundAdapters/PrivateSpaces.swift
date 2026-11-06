import ApplicationServices
import Foundation

/// Spaces and window ids through private APIs. With a symbol missing, windows have no id or no Space, or the Current
/// Space is unknown: either way no app is hidden for living in another Space
/// (`docs/adr/0001-private-apis-native-stack.md`).
enum PrivateSpaces {
    private typealias MainConnection = @convention(c) () -> UInt32
    private typealias GetActiveSpace = @convention(c) (UInt32) -> UInt64
    private typealias CopyManagedDisplaySpaces = @convention(c) (UInt32) -> Unmanaged<CFArray>?
    private typealias CopySpacesForWindows = @convention(c) (UInt32, Int32, CFArray) -> Unmanaged<CFArray>?
    private typealias AXGetWindow = @convention(c) (AXUIElement, UnsafeMutablePointer<CGWindowID>) -> AXError

    private static let mainConnection = PrivateSymbol.resolve(
        "CGSMainConnectionID", in: .skyLight, as: MainConnection.self)
    private static let getActiveSpace = PrivateSymbol.resolve(
        "CGSGetActiveSpace", in: .skyLight, as: GetActiveSpace.self)
    private static let copyManagedDisplaySpaces = PrivateSymbol.resolve(
        "CGSCopyManagedDisplaySpaces", in: .skyLight, as: CopyManagedDisplaySpaces.self)
    private static let copySpacesForWindows = PrivateSymbol.resolve(
        "CGSCopySpacesForWindows", in: .skyLight, as: CopySpacesForWindows.self)
    private static let axGetWindow = PrivateSymbol.resolve(
        "_AXUIElementGetWindow", in: .process, as: AXGetWindow.self)

    struct DisplaySpaces {
        /// One per display.
        var current: Set<UInt64> = []
        var fullScreen: Set<UInt64> = []
        /// The Current Space of the display with the keyboard focus.
        var active: UInt64?

        var isActiveFullScreen: Bool {
            active.map(fullScreen.contains) ?? false
        }
    }

    static func displaySpaces() -> DisplaySpaces {
        guard let mainConnection, let copyManagedDisplaySpaces,
            let displays = copyManagedDisplaySpaces(mainConnection())?.takeRetainedValue() as? [[String: Any]]
        else { return DisplaySpaces() }
        var result = DisplaySpaces()
        result.active = getActiveSpace.map { $0(mainConnection()) }.flatMap { $0 == 0 ? nil : $0 }
        for display in displays {
            if let current = (display["Current Space"] as? [String: Any])?["id64"] as? UInt64 {
                result.current.insert(current)
            }
            for space in display["Spaces"] as? [[String: Any]] ?? [] {
                if space["type"] as? Int == fullScreenSpaceType, let id = space["id64"] as? UInt64 {
                    result.fullScreen.insert(id)
                }
            }
        }
        return result
    }

    static func spaces(of windowID: CGWindowID) -> Set<UInt64> {
        let allSpacesMask: Int32 = 7
        guard let mainConnection, let copySpacesForWindows,
            let spaces = copySpacesForWindows(mainConnection(), allSpacesMask, [windowID] as CFArray)?
                .takeRetainedValue() as? [UInt64]
        else { return [] }
        return Set(spaces)
    }

    static func windowID(of element: AXUIElement) -> CGWindowID? {
        var id = CGWindowID(0)
        guard let axGetWindow, axGetWindow(element, &id) == .success, id != 0 else { return nil }
        return id
    }

    private static let fullScreenSpaceType = 4
}
