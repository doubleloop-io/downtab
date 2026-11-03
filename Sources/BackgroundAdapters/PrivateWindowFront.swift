import ApplicationServices
import Foundation

/// Makes one window the front and key window of its app through private APIs: the public ones bring every window
/// of the app forward (`docs/spike-results.md`, "Ricetta: alzare una finestra").
enum PrivateWindowFront {
    private typealias SetFrontProcess =
        @convention(c) (UnsafeMutablePointer<ProcessSerialNumber>, CGWindowID, UInt32) -> Int32
    private typealias PostEventRecord =
        @convention(c) (UnsafeMutablePointer<ProcessSerialNumber>, UnsafeMutablePointer<UInt8>) -> Int32
    private typealias ProcessForPID = @convention(c) (pid_t, UnsafeMutablePointer<ProcessSerialNumber>) -> OSStatus

    private static let setFrontProcess = PrivateSymbol.resolve(
        "_SLPSSetFrontProcessWithOptions", in: .skyLight, as: SetFrontProcess.self)
    private static let postEventRecord = PrivateSymbol.resolve(
        "SLPSPostEventRecordTo", in: .skyLight, as: PostEventRecord.self)
    private static let processForPID = PrivateSymbol.resolve("GetProcessForPID", in: .process, as: ProcessForPID.self)

    /// False when a symbol is missing or the process is gone: the caller falls back to public APIs.
    static func bringToFront(_ windowID: CGWindowID, of pid: pid_t) -> Bool {
        guard let setFrontProcess, let postEventRecord, let processForPID else { return false }
        var psn = ProcessSerialNumber()
        guard processForPID(pid, &psn) == noErr else { return false }
        let userGenerated: UInt32 = 0x200
        _ = setFrontProcess(&psn, windowID, userGenerated)
        var record = keyWindowRecord(windowID)
        _ = record.withUnsafeMutableBufferPointer { bytes in
            bytes.baseAddress.map { postEventRecord(&psn, $0) }
        }
        return true
    }

    /// Mouse-down only, aimed far off the window: an up would complete a real click, and points near the frame
    /// resize the window on macOS 27. Longer than the declared length because the window server reads past it.
    private static func keyWindowRecord(_ windowID: CGWindowID) -> [UInt8] {
        var bytes = [UInt8](repeating: 0, count: 0x100)
        bytes[0x04] = 0xf8
        bytes[0x08] = 0x01
        bytes[0x3a] = 0x10
        withUnsafeBytes(of: CGPoint(x: 300_000, y: 300_000)) { bytes.replaceSubrange(0x20..<0x20 + $0.count, with: $0) }
        withUnsafeBytes(of: windowID) { bytes.replaceSubrange(0x3c..<0x3c + $0.count, with: $0) }
        return bytes
    }
}
