import Carbon
import os

/// Receives Carbon hot key presses and reports the pressed hot key's id on the main actor.
public final class HotKeyPressHandler {
    /// Shared with the Carbon callback through its context pointer.
    fileprivate final class Relay: Sendable {
        let onPress: @MainActor @Sendable (UInt32) -> Void

        init(onPress: @escaping @MainActor @Sendable (UInt32) -> Void) {
            self.onPress = onPress
        }
    }

    private let logger = Logger(subsystem: "io.github.iacoware.downtab", category: "keyboard")
    private var relay: Relay?
    private var handler: EventHandlerRef?

    public init() {}

    public func install(onPress: @escaping @MainActor @Sendable (UInt32) -> Void) {
        let relay = Relay(onPress: onPress)
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let status = InstallEventHandler(
            GetEventDispatcherTarget(),
            handleHotKeyEvent,
            1,
            &spec,
            Unmanaged.passUnretained(relay).toOpaque(),
            &handler
        )
        guard status == noErr else {
            logger.error("shortcut handler failed: \(status)")
            return
        }
        self.relay = relay
    }
}

/// A named function, not an inline closure: Carbon is not concurrency-audited (see `ModifierReleaseTap`).
private func handleHotKeyEvent(
    handlerCall: EventHandlerCallRef?,
    event: EventRef?,
    context: UnsafeMutableRawPointer?
) -> OSStatus {
    guard let context else { return OSStatus(eventNotHandledErr) }
    var id = EventHotKeyID()
    let status = GetEventParameter(
        event,
        EventParamName(kEventParamDirectObject),
        EventParamType(typeEventHotKeyID),
        nil,
        MemoryLayout<EventHotKeyID>.size,
        nil,
        &id
    )
    guard status == noErr else { return status }
    let relay = Unmanaged<HotKeyPressHandler.Relay>.fromOpaque(context).takeUnretainedValue()
    // Carbon dispatches hot key events on the main run loop.
    MainActor.assumeIsolated { relay.onPress(id.id) }
    return noErr
}
