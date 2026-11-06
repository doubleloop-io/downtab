import ApplicationServices
import Foundation

/// `kAXWindows` lists only the windows of the Current Space: the Accessibility element of a window in another Space is
/// found by trying the app's element ids one by one (`docs/adr/0001-private-apis-native-stack.md`).
enum PrivateRemoteWindow {
    private typealias CreateWithRemoteToken = @convention(c) (CFData) -> Unmanaged<AXUIElement>?

    private static let createWithRemoteToken = PrivateSymbol.resolve(
        "_AXUIElementCreateWithRemoteToken", in: .process, as: CreateWithRemoteToken.self)

    /// Window elements of real apps sit well below it.
    private static let elementIDs: Range<UInt64> = 0..<1000
    /// Activation already happened: past this the Space switch is late enough to be worth giving up on.
    private static let budget: Duration = .milliseconds(150)

    struct Search {
        let element: AXUIElement?
    }

    /// Nil when the symbol is missing.
    static func element(of windowID: CGWindowID, of pid: pid_t) -> Search? {
        guard let createWithRemoteToken else { return nil }
        let clock = ContinuousClock()
        let start = clock.now
        var token = remoteToken(pid: pid)
        for elementID in elementIDs {
            if clock.now - start > budget { break }
            withUnsafeBytes(of: elementID) { token.replaceSubrange(12..<20, with: $0) }
            guard let element = createWithRemoteToken(token as CFData)?.takeRetainedValue() else { continue }
            AXUIElementSetMessagingTimeout(element, Accessibility.messagingTimeout)
            // The window id first: one message rules out almost every element.
            if PrivateSpaces.windowID(of: element) == windowID,
                AXAttribute.string(of: element, kAXRoleAttribute) == kAXWindowRole
            {
                return Search(element: element)
            }
        }
        return Search(element: nil)
    }

    /// 20 bytes: pid, 0, the "coco" magic, then the 8-byte element id filled in per attempt.
    private static func remoteToken(pid: pid_t) -> Data {
        var token = Data(count: 20)
        withUnsafeBytes(of: Int32(pid)) { token.replaceSubrange(0..<4, with: $0) }
        withUnsafeBytes(of: Int32(0)) { token.replaceSubrange(4..<8, with: $0) }
        withUnsafeBytes(of: Int32(0x636f_636f)) { token.replaceSubrange(8..<12, with: $0) }
        return token
    }
}
