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

    /// Downtab is never the active app: only a tracking area that is always active reports the pointer moving.
    /// Owned by the panel, so its events reach `mouseMoved(with:)` even if they bypass `sendEvent(_:)`.
    func trackPointer() {
        let options: NSTrackingArea.Options = [.mouseMoved, .activeAlways, .inVisibleRect]
        contentView?.addTrackingArea(NSTrackingArea(rect: .zero, options: options, owner: self, userInfo: nil))
    }

    /// Taken here, before the views: the first click on a panel that is not key is not lost either.
    override func sendEvent(_ event: NSEvent) {
        if PointerInput.isPointerEvent(event) {
            receivePointer(event)
        } else {
            super.sendEvent(event)
        }
    }

    override func mouseMoved(with event: NSEvent) {
        receivePointer(event)
    }

    private func receivePointer(_ event: NSEvent) {
        // Before the show delay the Switcher is transparent: there is nothing to point at.
        guard alphaValue > 0 else { return }
        pointer?.receive(event, over: pointerTarget(at: event.locationInWindow))
    }
}
