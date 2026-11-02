import CoreGraphics
import Foundation

private var onOptionReleased: (() -> Void)?
private var tapPort: CFMachPort?

/// Listen-only and on its own thread, so a busy main thread can neither delay events nor get the tap disabled.
enum OptionReleaseTap {
    static var isOptionDown: Bool {
        CGEventSource.flagsState(.combinedSessionState).contains(.maskAlternate)
    }

    static func start(_ handler: @escaping () -> Void) -> Bool {
        onOptionReleased = handler
        let mask = CGEventMask(1 << CGEventType.flagsChanged.rawValue)
        guard let port = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap, options: .listenOnly,
                                           eventsOfInterest: mask, callback: { _, type, event, _ in
            switch type {
            case .tapDisabledByTimeout, .tapDisabledByUserInput:
                Log.write("tap_disabled reason=\(type.rawValue)")
                if let tapPort { CGEvent.tapEnable(tap: tapPort, enable: true) }
                Log.write("tap_reenabled by=callback")
            case .flagsChanged where !event.flags.contains(.maskAlternate):
                onOptionReleased?()
            default:
                break
            }
            return nil
        }, userInfo: nil) else { return false }
        tapPort = port
        let thread = Thread {
            CFRunLoopAddSource(CFRunLoopGetCurrent(), CFMachPortCreateRunLoopSource(nil, port, 0), .commonModes)
            CFRunLoopRun()
        }
        thread.qualityOfService = .userInteractive
        thread.start()
        startWatchdog(port)
        return true
    }

    /// `kill -USR1` simulates macOS disabling the tap, which cannot be provoked on demand.
    private static func startWatchdog(_ port: CFMachPort) {
        signal(SIGUSR1, SIG_IGN)
        let simulate = DispatchSource.makeSignalSource(signal: SIGUSR1, queue: .global())
        simulate.setEventHandler {
            CGEvent.tapEnable(tap: port, enable: false)
            Log.write("tap_disabled reason=simulated")
        }
        simulate.resume()
        let watchdog = DispatchSource.makeTimerSource(queue: .global())
        watchdog.schedule(deadline: .now() + 1, repeating: 1)
        watchdog.setEventHandler {
            _ = simulate
            if !CGEvent.tapIsEnabled(tap: port) {
                CGEvent.tapEnable(tap: port, enable: true)
                Log.write("tap_reenabled by=watchdog")
            }
        }
        watchdog.resume()
        retainedWatchdog = watchdog
    }

    private static var retainedWatchdog: DispatchSourceTimer?
}
