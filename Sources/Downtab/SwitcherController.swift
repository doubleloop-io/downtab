import AppKit
import BackgroundAdapters
import SwitcherCore
import os

final class SwitcherController {
    private var switcher = Switcher()
    private let tracker = DesktopTracker()
    private let panel = SwitcherPanel()
    private let focuser = WindowFocuser()
    private let logger = Logger(subsystem: "io.doubleloop.downtab", category: "keyboard")
    private var missedReleaseCheck: Task<Void, Never>?
    private var showDelay: Task<Void, Never>?
    private(set) lazy var keyboard = KeyboardInput { [weak self] event in self?.handle(event) }
    private(set) lazy var pointer = PointerInput { [weak self] event in self?.handle(event) }

    func start() {
        tracker.start()
        keyboard.start()
        panel.attach(pointer)
    }

    private func handle(_ event: SwitcherEvent) {
        let previous = switcher.state
        switcher.shortcuts = keyboard.shortcuts
        let desktop = tracker.snapshot(freshWindowOrder: mayOpen(previous, event))
        let effect = switcher.handle(event, desktop: desktop)
        // Re-showing an unchanged state would choose the display again, e.g. move the panel to the pointer's.
        if switcher.state != previous {
            render()
            keyboard.captureSwitcherKeys(switcher.state != .closed)
            pointer.switcherChanged(frames: switcher.state == .closed ? nil : panel.pointerFrames)
            updateMissedReleaseCheck()
            updateShowDelay()
        }
        if let effect {
            Task { [focuser] in await focuser.perform(effect) }
        }
    }

    /// Only a shortcut pressed while closed opens. The App row is fixed at opening, so the window server is not
    /// queried on every keypress while open, nor on every modifier change while closed.
    private func mayOpen(_ state: SwitcherState, _ event: SwitcherEvent) -> Bool {
        guard state == .closed, case .keyPressed = event else { return false }
        return true
    }

    private func render() {
        switch switcher.state {
        case .closed:
            panel.hide()
        case .open(let displayed):
            panel.show(displayed, icon: tracker.icon(for:))
        }
    }

    private func updateShowDelay() {
        switch switcher.state {
        case .closed:
            showDelay?.cancel()
            showDelay = nil
        case .open:
            guard showDelay == nil else { return }
            showDelay = Task { [weak self] in
                guard (try? await Task.sleep(for: Switcher.showDelay)) != nil else { return }
                // Closing may have cancelled this delay while it was resuming.
                guard !Task.isCancelled, let self else { return }
                handle(.showDelayElapsed)
            }
        }
    }

    private func updateMissedReleaseCheck() {
        switch switcher.state {
        case .closed:
            missedReleaseCheck?.cancel()
            missedReleaseCheck = nil
        case .open(let displayed):
            guard missedReleaseCheck == nil else { return }
            let modifier = displayed.modifier
            let fallback = ModifierReleaseFallback { modifier.isSubset(of: ModifierReleaseTap.heldModifiers) }
            missedReleaseCheck = Task { [weak self] in
                guard (try? await fallback.waitForRelease()) != nil else { return }
                // The tap's release may have closed the Switcher while this check was resuming.
                guard !Task.isCancelled, let self else { return }
                logger.info("modifier release confirmed by fallback check")
                handle(.modifiersChanged(held: ModifierReleaseTap.heldModifiers))
            }
        }
    }
}
