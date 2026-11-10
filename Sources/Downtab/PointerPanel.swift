import AppKit
import SwitcherCore

/// A panel of the Switcher whose pointer events go to `PointerInput`, never to its views: the Window list's scroll
/// view does not scroll by itself, and no click activates Downtab.
class PointerPanel: NSPanel {
    private(set) var pointer: PointerInput?

    func attach(_ pointer: PointerInput) {
        self.pointer = pointer
    }

    /// The item under `location`, in window coordinates; nil between items.
    func pointerTarget(at location: NSPoint) -> PointerTarget? {
        nil
    }

    /// The item under `point`, in screen coordinates; nil outside the panel or between items.
    func pointerTarget(atScreen point: NSPoint) -> PointerTarget? {
        guard isVisible, frame.contains(point) else { return nil }
        return pointerTarget(at: convertPoint(fromScreen: point))
    }

    /// Taken here, before the views: the first click on a panel that is not key is not lost either.
    override func sendEvent(_ event: NSEvent) {
        if PointerInput.isPointerEvent(event) {
            receivePointer(event, over: pointerTarget(at: event.locationInWindow))
        } else {
            super.sendEvent(event)
        }
    }

    func receivePointer(_ event: NSEvent, over target: PointerTarget?) {
        // Before the show delay the Switcher is transparent: there is nothing to point at.
        guard alphaValue > 0 else { return }
        pointer?.receive(event, over: target)
    }
}
