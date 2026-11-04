import Foundation
import os

/// Private APIs are resolved at run time: a symbol macOS removed costs one log line and its feature, never a crash.
public enum PrivateSymbol {
    public enum Library: Sendable {
        /// Everything already loaded in the process.
        case process
        case skyLight
    }

    private static let logger = Logger(subsystem: "io.github.iacoware.downtab", category: "private-api")

    /// Returns nil, after logging one line (to `logMissing` when given, else to the unified log), when the symbol
    /// is not there.
    public static func resolve<Function>(
        _ name: String,
        in library: Library,
        as _: Function.Type,
        logMissing: ((String) -> Void)? = nil
    ) -> Function? {
        guard let pointer = dlsym(handle(of: library), name) else {
            let line = "private symbol missing: \(name), its feature is off"
            if let logMissing {
                logMissing(line)
            } else {
                logger.error("\(line, privacy: .public)")
            }
            return nil
        }
        return unsafeBitCast(pointer, to: Function.self)
    }

    private static func handle(of library: Library) -> UnsafeMutableRawPointer? {
        switch library {
        case .process:
            UnsafeMutableRawPointer(bitPattern: -2)  // RTLD_DEFAULT, not imported into Swift.
        case .skyLight:
            dlopen("/System/Library/PrivateFrameworks/SkyLight.framework/SkyLight", RTLD_LAZY)
        }
    }
}
