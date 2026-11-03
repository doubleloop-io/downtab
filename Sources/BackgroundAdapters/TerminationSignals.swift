import Foundation

/// On SIGTERM (`make stop`, logout), SIGINT or SIGHUP: runs `cleanUp`, then dies of the signal as if unhandled.
/// SIGKILL and crashes skip it: Emergency restore covers those.
public final class TerminationSignals {
    private static let handled = [SIGTERM, SIGINT, SIGHUP]
    private var sources: [any DispatchSourceSignal] = []

    public init() {}

    public func install(cleanUp: @escaping @Sendable () -> Void) {
        sources = Self.handled.map { number in
            signal(number, SIG_IGN)
            // Signal handlers may only call async-signal-safe functions, and restoring the native shortcuts is not
            // one: a dispatch source runs it as normal code. Swift concurrency offers no signal API.
            // swiftlint:disable:next no_dispatch
            let source = DispatchSource.makeSignalSource(signal: number, queue: .global())
            source.setEventHandler {
                cleanUp()
                signal(number, SIG_DFL)
                raise(number)
            }
            source.resume()
            return source
        }
    }
}
