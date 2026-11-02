import ApplicationServices
import Foundation

// Resolved at runtime so a symbol removed by macOS degrades to a log line, not a launch failure.
enum PrivateAPI {
    private static let skyLight = dlopen("/System/Library/PrivateFrameworks/SkyLight.framework/SkyLight", RTLD_LAZY)

    private static func symbol<T>(_ name: String, in handle: UnsafeMutableRawPointer?, as _: T.Type) -> T? {
        guard let pointer = dlsym(handle, name) else {
            Log.write("private_symbol_missing \(name)")
            return nil
        }
        return unsafeBitCast(pointer, to: T.self)
    }

    private typealias MainConnection = @convention(c) () -> UInt32
    private typealias CopySpaces = @convention(c) (UInt32) -> Unmanaged<CFArray>?
    private typealias SpacesForWindows = @convention(c) (UInt32, Int32, CFArray) -> Unmanaged<CFArray>?
    private typealias FrontProcess = @convention(c) (UnsafeMutablePointer<ProcessSerialNumber>, CGWindowID, UInt32) -> Int32
    private typealias PostRecord = @convention(c) (UnsafeMutablePointer<ProcessSerialNumber>, UnsafeMutablePointer<UInt8>) -> Int32
    private typealias AXGetWindow = @convention(c) (AXUIElement, UnsafeMutablePointer<CGWindowID>) -> AXError
    private typealias ProcessForPID = @convention(c) (pid_t, UnsafeMutablePointer<ProcessSerialNumber>) -> OSStatus

    private static let mainConnection = symbol("CGSMainConnectionID", in: skyLight, as: MainConnection.self)
    private static let copySpaces = symbol("CGSCopyManagedDisplaySpaces", in: skyLight, as: CopySpaces.self)
    private static let spacesForWindows = symbol("CGSCopySpacesForWindows", in: skyLight, as: SpacesForWindows.self)
    private static let frontProcess = symbol("_SLPSSetFrontProcessWithOptions", in: skyLight, as: FrontProcess.self)
    private static let postRecord = symbol("SLPSPostEventRecordTo", in: skyLight, as: PostRecord.self)
    private static let axGetWindow = symbol("_AXUIElementGetWindow", in: UnsafeMutableRawPointer(bitPattern: -2), as: AXGetWindow.self)
    private static let processForPID = symbol("GetProcessForPID", in: UnsafeMutableRawPointer(bitPattern: -2), as: ProcessForPID.self)

    static func windowID(of element: AXUIElement) -> CGWindowID? {
        var id = CGWindowID(0)
        guard let axGetWindow, axGetWindow(element, &id) == .success, id != 0 else { return nil }
        return id
    }

    static func currentSpaceIDs() -> Set<UInt64> {
        guard let mainConnection, let copySpaces,
              let displays = copySpaces(mainConnection())?.takeRetainedValue() as? [[String: Any]] else { return [] }
        return Set(displays.compactMap { ($0["Current Space"] as? [String: Any])?["id64"] as? UInt64 })
    }

    static func spaces(of windowID: CGWindowID) -> [UInt64] {
        let allSpacesMask: Int32 = 7
        guard let mainConnection, let spacesForWindows,
              let spaces = spacesForWindows(mainConnection(), allSpacesMask, [windowID] as CFArray)?.takeRetainedValue() as? [UInt64]
        else { return [] }
        return spaces
    }

    /// Returns the two CGError values, or nil when a symbol is unavailable.
    static func frontWindow(pid: pid_t, windowID: CGWindowID) -> (front: Int32, key: Int32)? {
        guard let frontProcess, let postRecord, let processForPID else { return nil }
        var psn = ProcessSerialNumber()
        guard processForPID(pid, &psn) == noErr else { return nil }
        let userGenerated: UInt32 = 0x200
        let front = frontProcess(&psn, windowID, userGenerated)
        return (front, postRecord(&psn, makeKeyRecord(windowID)))
    }

    /// Mouse-down only, aimed far off the window: an up would complete a real click, and points near the
    /// frame resize the window on macOS 27. Buffer is longer than the record because WindowServer reads past it.
    private static func makeKeyRecord(_ windowID: CGWindowID) -> UnsafeMutablePointer<UInt8> {
        let size = 0x100
        let bytes = UnsafeMutablePointer<UInt8>.allocate(capacity: size)
        bytes.initialize(repeating: 0, count: size)
        bytes[0x04] = 0xf8
        bytes[0x08] = 0x01
        bytes[0x3a] = 0x10
        var point = CGPoint(x: 300_000, y: 300_000)
        var id = windowID
        memcpy(bytes + 0x20, &point, MemoryLayout<CGPoint>.size)
        memcpy(bytes + 0x3c, &id, MemoryLayout<CGWindowID>.size)
        return bytes
    }
}
