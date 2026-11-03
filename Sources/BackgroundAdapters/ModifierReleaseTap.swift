// CF run loop sources are thread-safe but not marked Sendable; the source must move to the tap thread.
@preconcurrency import CoreFoundation
import CoreGraphics
import Foundation
public import SwitcherCore
import Synchronization
import os

/// Reports the modifiers held whenever they change anywhere in the session, so a Modifier release is never missed.
/// Listen-only and on its own thread, so a busy main thread can neither delay events nor get the tap disabled.
public final class ModifierReleaseTap {
    /// Shared with the tap thread through the callback's context pointer.
    fileprivate final class Relay: Sendable {
        let onChange: @MainActor @Sendable (Set<ShortcutModifier>) -> Void
        let port = Mutex<CFMachPort?>(nil)
        let logger = Logger(subsystem: "local.downtab", category: "keyboard")

        init(onChange: @escaping @MainActor @Sendable (Set<ShortcutModifier>) -> Void) {
            self.onChange = onChange
        }

        /// The system disables a tap it deems slow; re-enabling from the tap thread needs no main-actor hop.
        func reenable(disabledBy reason: String) {
            logger.info("modifier release tap disabled by \(reason, privacy: .public)")
            let reenabled = port.withLock { port in
                guard let port else { return false }
                CGEvent.tapEnable(tap: port, enable: true)
                return true
            }
            if reenabled { logger.info("modifier release tap re-enabled") }
        }

        /// Left disabled on purpose: macOS sends no disable event for it, so only the fallback check confirms.
        func simulateDisable() {
            port.withLock { port in
                guard let port else { return }
                CGEvent.tapEnable(tap: port, enable: false)
            }
            logger.info("modifier release tap disabled by simulation")
        }
    }

    public static var heldModifiers: Set<ShortcutModifier> {
        held(in: CGEventSource.flagsState(.combinedSessionState))
    }

    fileprivate static func held(in flags: CGEventFlags) -> Set<ShortcutModifier> {
        Set(ShortcutModifier.allCases.filter { flags.contains(flag(of: $0)) })
    }

    private static func flag(of modifier: ShortcutModifier) -> CGEventFlags {
        switch modifier {
        case .control: .maskControl
        case .option: .maskAlternate
        case .shift: .maskShift
        case .command: .maskCommand
        }
    }

    private var relay: Relay?
    private var simulatedDisableSignal: (any DispatchSourceSignal)?

    public init() {}

    /// Does nothing once the tap runs: the permission may be granted again after a revocation.
    public func start(onChange: @escaping @MainActor @Sendable (Set<ShortcutModifier>) -> Void) {
        guard relay == nil else { return }
        let relay = Relay(onChange: onChange)
        let mask = CGEventMask(1 << CGEventType.flagsChanged.rawValue)
        guard
            let port = CGEvent.tapCreate(
                tap: .cgSessionEventTap,
                place: .headInsertEventTap,
                options: .listenOnly,
                eventsOfInterest: mask,
                callback: handleTapEvent,
                userInfo: Unmanaged.passUnretained(relay).toOpaque()
            )
        else {
            relay.logger.error("modifier release tap failed: is the Accessibility permission granted?")
            return
        }
        relay.port.withLock { $0 = port }
        self.relay = relay
        let source = CFMachPortCreateRunLoopSource(nil, port, 0)
        let thread = Thread {
            CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes)
            CFRunLoopRun()
        }
        thread.name = "modifier-release-tap"
        thread.qualityOfService = .userInteractive
        thread.start()
        listenForSimulatedDisable(relay)
        // `make smoke` waits for this exact line before posting events.
        relay.logger.info("modifier release tap started")
    }

    /// `pkill -USR1 -x Downtab` disables the tap, since macOS disabling it cannot be provoked on demand.
    private func listenForSimulatedDisable(_ relay: Relay) {
        signal(SIGUSR1, SIG_IGN)
        let source = DispatchSource.makeSignalSource(signal: SIGUSR1, queue: .global())
        source.setEventHandler { relay.simulateDisable() }
        source.resume()
        simulatedDisableSignal = source
    }
}

/// Runs on the tap thread. A named function, not an inline closure: CoreGraphics is not concurrency-audited,
/// so an inline closure touching main-actor state only gets a warning that escapes warnings-as-errors.
private func handleTapEvent(
    proxy: CGEventTapProxy,
    type: CGEventType,
    event: CGEvent,
    context: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    guard let context else { return nil }
    let relay = Unmanaged<ModifierReleaseTap.Relay>.fromOpaque(context).takeUnretainedValue()
    switch type {
    case .tapDisabledByTimeout:
        relay.reenable(disabledBy: "timeout")
    case .tapDisabledByUserInput:
        relay.reenable(disabledBy: "user input")
    case .flagsChanged:
        let held = ModifierReleaseTap.held(in: event.flags)
        Task { @MainActor in relay.onChange(held) }
    default:
        break
    }
    return nil
}
