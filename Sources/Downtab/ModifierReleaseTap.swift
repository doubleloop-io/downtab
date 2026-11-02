// CF run loop sources are thread-safe but not marked Sendable; the source must move to the tap thread.
@preconcurrency import CoreFoundation
import CoreGraphics
import Foundation
import os

/// Detects the Modifier (⌥) going up anywhere in the session.
/// Listen-only and on its own thread, so a busy main thread can neither delay events nor get the tap disabled.
final class ModifierReleaseTap {
    /// Hands tap callbacks, which run on the tap thread, over to the main actor.
    nonisolated fileprivate final class Relay: Sendable {
        let onRelease: @MainActor @Sendable () -> Void
        let onDisabled: @MainActor @Sendable () -> Void

        init(
            onRelease: @escaping @MainActor @Sendable () -> Void, onDisabled: @escaping @MainActor @Sendable () -> Void
        ) {
            self.onRelease = onRelease
            self.onDisabled = onDisabled
        }
    }

    /// ⌥, the only Modifier until shortcuts are configurable.
    nonisolated fileprivate static let modifier = CGEventFlags.maskAlternate

    static var isModifierDown: Bool {
        CGEventSource.flagsState(.combinedSessionState).contains(modifier)
    }

    private let logger = Logger(subsystem: "local.downtab", category: "keyboard")
    private var port: CFMachPort?
    private var relay: Relay?

    func start(onRelease: @escaping @MainActor @Sendable () -> Void) {
        let relay = Relay(onRelease: onRelease, onDisabled: { [weak self] in self?.reenable() })
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
            logger.error("modifier release tap failed: is the Accessibility permission granted?")
            return
        }
        self.relay = relay
        self.port = port
        let source = CFMachPortCreateRunLoopSource(nil, port, 0)
        let thread = Thread {
            CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes)
            CFRunLoopRun()
        }
        thread.name = "modifier-release-tap"
        thread.qualityOfService = .userInteractive
        thread.start()
        logger.info("modifier release tap started")
    }

    private func reenable() {
        guard let port else { return }
        CGEvent.tapEnable(tap: port, enable: true)
        logger.info("modifier release tap re-enabled")
    }
}

/// Runs on the tap thread: nonisolated, because the target's default main-actor isolation
/// would make the runtime trap on the first event.
nonisolated private func handleTapEvent(
    proxy: CGEventTapProxy,
    type: CGEventType,
    event: CGEvent,
    context: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    guard let context else { return nil }
    let relay = Unmanaged<ModifierReleaseTap.Relay>.fromOpaque(context).takeUnretainedValue()
    switch type {
    case .tapDisabledByTimeout, .tapDisabledByUserInput:
        Task { @MainActor in relay.onDisabled() }
    case .flagsChanged where !event.flags.contains(ModifierReleaseTap.modifier):
        Task { @MainActor in relay.onRelease() }
    default:
        break
    }
    return nil
}
