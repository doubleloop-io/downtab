// CF run loop sources are thread-safe but not marked Sendable; the source must move to the tap thread.
@preconcurrency import CoreFoundation
import CoreGraphics
import Foundation
public import SwitcherCore
import Synchronization
import os

/// Takes keys while the Switcher is open, before hot keys are matched:
/// - Esc: another app or the system may hold Esc with the Modifier (⌘Esc is taken system-wide), so it would never
///   reach the Switcher.
/// - The repeats of a held shortcut key: a Carbon hot key fires once per press and drops its repeats.
/// Active, so it can swallow the keys; on its own thread, so a busy main thread cannot get the tap disabled.
public final class SwitcherKeyTap: Sendable {
    /// Shared with the tap thread through the callback's context pointer.
    fileprivate final class Relay: Sendable {
        let onEvent: @MainActor @Sendable (SwitcherEvent) -> Void
        let port = Mutex<CFMachPort?>(nil)
        let isCapturing = Mutex(false)
        let shortcutKeyCodes = Mutex<Set<Int64>>([])
        /// Esc's key up follows its key down out of the Frontmost app, even once the Switcher closed.
        let isSwallowingKeyUp = Mutex(false)
        let logger = Logger(subsystem: "io.doubleloop.downtab", category: "keyboard")

        init(onEvent: @escaping @MainActor @Sendable (SwitcherEvent) -> Void) {
            self.onEvent = onEvent
        }

        func reenable(disabledBy reason: String) {
            logger.info("switcher key tap disabled by \(reason, privacy: .public)")
            port.withLock { port in
                guard let port else { return }
                CGEvent.tapEnable(tap: port, enable: true)
            }
        }
    }

    private let relay = Mutex<Relay?>(nil)

    public init() {}

    /// Does nothing once the tap runs: the permission may be granted again after a revocation.
    public func start(onEvent: @escaping @MainActor @Sendable (SwitcherEvent) -> Void) {
        let started = relay.withLock { current -> Relay? in
            guard current == nil else { return nil }
            current = Relay(onEvent: onEvent)
            return current
        }
        guard let relay = started else { return }
        let mask = CGEventMask((1 << CGEventType.keyDown.rawValue) | (1 << CGEventType.keyUp.rawValue))
        guard
            let port = CGEvent.tapCreate(
                tap: .cgSessionEventTap,
                place: .headInsertEventTap,
                options: .defaultTap,
                eventsOfInterest: mask,
                callback: handleSwitcherKeyTapEvent,
                userInfo: Unmanaged.passUnretained(relay).toOpaque()
            )
        else {
            relay.logger.error("switcher key tap failed: is the Accessibility permission granted?")
            self.relay.withLock { $0 = nil }
            return
        }
        relay.port.withLock { $0 = port }
        let source = CFMachPortCreateRunLoopSource(nil, port, 0)
        let thread = Thread {
            CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes)
            CFRunLoopRun()
        }
        thread.name = "switcher-key-tap"
        thread.qualityOfService = .userInteractive
        thread.start()
    }

    /// While false, Esc and the shortcut keys pass through untouched.
    public func setCapturing(_ isCapturing: Bool) {
        relay.withLock { $0 }?.isCapturing.withLock { $0 = isCapturing }
    }

    /// The keys of the App and Window shortcuts, whose repeats are taken while capturing.
    public func setShortcuts(_ shortcuts: Shortcuts) {
        let keyCodes = Set(ShortcutSlot.allCases.map { Int64(shortcuts[$0].keyCode) })
        relay.withLock { $0 }?.shortcutKeyCodes.withLock { $0 = keyCodes }
    }
}

private let escapeKeyCode: Int64 = 53

/// Runs on the tap thread. A named function, not an inline closure: CoreGraphics is not concurrency-audited,
/// so an inline closure touching main-actor state only gets a warning that escapes warnings-as-errors.
private func handleSwitcherKeyTapEvent(
    proxy: CGEventTapProxy,
    type: CGEventType,
    event: CGEvent,
    context: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    let passThrough = Unmanaged.passUnretained(event)
    guard let context else { return passThrough }
    let relay = Unmanaged<SwitcherKeyTap.Relay>.fromOpaque(context).takeUnretainedValue()
    switch type {
    case .tapDisabledByTimeout:
        relay.reenable(disabledBy: "timeout")
    case .tapDisabledByUserInput:
        relay.reenable(disabledBy: "user input")
    case .keyDown where event.getIntegerValueField(.keyboardEventKeycode) == escapeKeyCode:
        // A held Esc repeats after closing the Switcher: the repeats are swallowed too, until its key up.
        let isRepeatOfSwallowed =
            event.getIntegerValueField(.keyboardEventAutorepeat) != 0 && relay.isSwallowingKeyUp.withLock { $0 }
        if isRepeatOfSwallowed { return nil }
        guard relay.isCapturing.withLock({ $0 }) else { return passThrough }
        relay.isSwallowingKeyUp.withLock { $0 = true }
        Task { @MainActor in relay.onEvent(.escapePressed) }
        return nil
    case .keyDown where event.getIntegerValueField(.keyboardEventAutorepeat) != 0:
        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        let isHeldShortcutKey =
            relay.isCapturing.withLock { $0 } && relay.shortcutKeyCodes.withLock { $0.contains(keyCode) }
        guard isHeldShortcutKey else { return passThrough }
        let repeated = Shortcut(keyCode: Int(keyCode), modifiers: ShortcutModifier.held(in: event.flags))
        Task { @MainActor in relay.onEvent(.keyRepeated(repeated)) }
        return nil
    case .keyUp where event.getIntegerValueField(.keyboardEventKeycode) == escapeKeyCode:
        let swallowed = relay.isSwallowingKeyUp.withLock { swallowing in
            defer { swallowing = false }
            return swallowing
        }
        return swallowed ? nil : passThrough
    default:
        break
    }
    return passThrough
}
