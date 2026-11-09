// CF run loop sources are thread-safe but not marked Sendable; the source must move to the tap thread.
@preconcurrency import CoreFoundation
import CoreGraphics
import Foundation
public import SwitcherCore
import Synchronization
import os

/// Takes the clicks outside the Switcher and its Window list while the Switcher is open: they cancel it and never
/// reach, or activate, the app underneath. Clicks inside pass, to the panels.
/// Active, so it can swallow the click; on its own thread, so a busy main thread cannot get the tap disabled.
public final class OutsideClickTap: Sendable {
    /// Shared with the tap thread through the callback's context pointer.
    fileprivate final class Relay: Sendable {
        let onClickOutside: @MainActor @Sendable () -> Void
        let port = Mutex<CFMachPort?>(nil)
        /// The Switcher's frames in window-server coordinates; nil while closed, so every click passes.
        let switcherFrames = Mutex<[ScreenRect]?>(nil)
        /// The buttons whose mouse down was swallowed: their drags and mouse up follow it, even once closed.
        let swallowedButtons = Mutex<Set<Int64>>([])
        let logger = Logger(subsystem: "io.doubleloop.downtab", category: "pointer")

        init(onClickOutside: @escaping @MainActor @Sendable () -> Void) {
            self.onClickOutside = onClickOutside
        }

        func reenable(disabledBy reason: String) {
            logger.info("outside click tap disabled by \(reason, privacy: .public)")
            port.withLock { port in
                guard let port else { return }
                CGEvent.tapEnable(tap: port, enable: true)
            }
        }

        func isOutsideSwitcher(_ point: CGPoint) -> Bool {
            guard let frames = switcherFrames.withLock({ $0 }) else { return false }
            return !frames.contains { frame in
                CGRect(x: frame.x, y: frame.y, width: frame.width, height: frame.height).contains(point)
            }
        }
    }

    private let relay = Mutex<Relay?>(nil)

    public init() {}

    /// Does nothing once the tap runs: the permission may be granted again after a revocation.
    public func start(onClickOutside: @escaping @MainActor @Sendable () -> Void) {
        let started = relay.withLock { current -> Relay? in
            guard current == nil else { return nil }
            current = Relay(onClickOutside: onClickOutside)
            return current
        }
        guard let relay = started else { return }
        let types: [CGEventType] = [
            .leftMouseDown, .leftMouseUp, .leftMouseDragged, .rightMouseDown, .rightMouseUp, .rightMouseDragged,
            .otherMouseDown, .otherMouseUp, .otherMouseDragged,
        ]
        let mask = types.reduce(CGEventMask(0)) { $0 | (CGEventMask(1) << CGEventMask($1.rawValue)) }
        guard
            let port = CGEvent.tapCreate(
                tap: .cgSessionEventTap,
                place: .headInsertEventTap,
                options: .defaultTap,
                eventsOfInterest: mask,
                callback: handleOutsideClickTapEvent,
                userInfo: Unmanaged.passUnretained(relay).toOpaque()
            )
        else {
            relay.logger.error("outside click tap failed: is the Accessibility permission granted?")
            self.relay.withLock { $0 = nil }
            return
        }
        relay.port.withLock { $0 = port }
        let source = CFMachPortCreateRunLoopSource(nil, port, 0)
        let thread = Thread {
            CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes)
            CFRunLoopRun()
        }
        thread.name = "outside-click-tap"
        thread.qualityOfService = .userInteractive
        thread.start()
    }

    /// `frames` are the Switcher's and its Window list's, in window-server coordinates (origin at the menu bar
    /// display's top-left corner, y down); empty, every click is outside. Nil while closed: every click passes.
    public func setCapturing(outside frames: [ScreenRect]?) {
        relay.withLock { $0 }?.switcherFrames.withLock { $0 = frames }
    }
}

/// Runs on the tap thread. A named function, not an inline closure: CoreGraphics is not concurrency-audited,
/// so an inline closure touching main-actor state only gets a warning that escapes warnings-as-errors.
private func handleOutsideClickTapEvent(
    proxy: CGEventTapProxy,
    type: CGEventType,
    event: CGEvent,
    context: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    let passThrough = Unmanaged.passUnretained(event)
    guard let context else { return passThrough }
    let relay = Unmanaged<OutsideClickTap.Relay>.fromOpaque(context).takeUnretainedValue()
    let button = event.getIntegerValueField(.mouseEventButtonNumber)
    switch type {
    case .tapDisabledByTimeout:
        relay.reenable(disabledBy: "timeout")
    case .tapDisabledByUserInput:
        relay.reenable(disabledBy: "user input")
    case .leftMouseDown, .rightMouseDown, .otherMouseDown:
        guard relay.isOutsideSwitcher(event.location) else { return passThrough }
        relay.swallowedButtons.withLock { _ = $0.insert(button) }
        Task { @MainActor in relay.onClickOutside() }
        return nil
    case .leftMouseDragged, .rightMouseDragged, .otherMouseDragged:
        return relay.swallowedButtons.withLock { $0.contains(button) } ? nil : passThrough
    case .leftMouseUp, .rightMouseUp, .otherMouseUp:
        return relay.swallowedButtons.withLock { $0.remove(button) } != nil ? nil : passThrough
    default:
        break
    }
    return passThrough
}
