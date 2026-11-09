import AppKit
import BackgroundAdapters
import SwitcherCore

/// Turns the mouse and the trackpad on the Switcher into Switcher events, and takes the clicks outside it.
/// The panels hand it their pointer events, each with the item under the pointer.
final class PointerInput {
    private let onEvent: (SwitcherEvent) -> Void
    private let outsideClicks = OutsideClickTap()
    /// The last item the pointer was on: only moving onto another one changes the selection, so neither a still
    /// pointer nor jitter inside an item overrides a selection made with the keyboard.
    private var hovered: PointerTarget?
    /// The item under a mouse down: a click acts on mouse up over the same item.
    private var pressed: PointerTarget?
    private var scrollStepper = ScrollStepper()

    init(onEvent: @escaping (SwitcherEvent) -> Void) {
        self.onEvent = onEvent
    }

    /// Clicks outside are taken only once the Accessibility permission is granted; calling again is harmless.
    func startEventTaps() {
        outsideClicks.start { [weak self] in self?.onEvent(.pointer(.clickedOutside)) }
    }

    /// Call whenever the Switcher changes. `frames` are the AppKit frames of the Switcher and its Window list
    /// while they show; nil once closed.
    func switcherChanged(frames: [NSRect]?) {
        guard let frames else {
            hovered = nil
            pressed = nil
            scrollStepper = ScrollStepper()
            outsideClicks.setCapturing(outside: nil)
            return
        }
        outsideClicks.setCapturing(outside: Self.windowServerFrames(frames))
    }

    static func isPointerEvent(_ event: NSEvent) -> Bool {
        switch event.type {
        case .mouseMoved, .mouseEntered, .mouseExited, .scrollWheel, .leftMouseDown, .leftMouseUp, .leftMouseDragged,
            .rightMouseDown, .rightMouseUp, .rightMouseDragged, .otherMouseDown, .otherMouseUp, .otherMouseDragged:
            true
        default:
            false
        }
    }

    /// `target` is the item under the pointer when the event happened, nil between items.
    func receive(_ event: NSEvent, over target: PointerTarget?) {
        switch event.type {
        case .mouseMoved, .leftMouseDragged:
            enter(target)
        case .leftMouseDown:
            pressed = target
        case .leftMouseUp:
            defer { pressed = nil }
            guard let target, target == pressed else { return }
            onEvent(.pointer(.clicked(target)))
        case .scrollWheel:
            scroll(event, over: target)
        default:
            break
        }
    }

    private func enter(_ target: PointerTarget?) {
        guard let target, target != hovered else { return }
        hovered = target
        onEvent(.pointer(.entered(target)))
    }

    private func scroll(_ event: NSEvent, over target: PointerTarget?) {
        guard let direction = scrollStepper.step(for: ScrollSample(event)) else { return }
        // Scrolling over an item selects it like hovering: moving inside it afterwards changes nothing.
        if let target { hovered = target }
        onEvent(.pointer(.scrolled(direction, over: target)))
    }

    /// The event tap sees window-server coordinates.
    private static func windowServerFrames(_ frames: [NSRect]) -> [ScreenRect] {
        // AppKit lists the menu bar display first.
        guard let menuBarDisplay = NSScreen.screens.first.map({ ScreenRect($0.frame) }) else { return [] }
        return frames.map { ScreenRect($0).flipped(around: menuBarDisplay) }
    }
}

extension ScrollSample {
    fileprivate init(_ event: NSEvent) {
        self.init(source: Self.source(of: event), deltaX: event.scrollingDeltaX, deltaY: event.scrollingDeltaY)
    }

    private static func source(of event: NSEvent) -> Source {
        if !event.momentumPhase.isEmpty { return .momentum }
        if !event.hasPreciseScrollingDeltas { return .wheel }
        let phase = event.phase
        if phase.contains(.began) || phase.contains(.mayBegin) { return .gesture(.began) }
        if phase.contains(.ended) || phase.contains(.cancelled) { return .gesture(.ended) }
        if phase.isEmpty { return .unphased(at: event.timestamp) }
        return .gesture(.changed)
    }
}
