import AppKit
import SwitcherCore

final class SwitcherController {
    private var switcher = Switcher()
    private let tracker = DesktopTracker()
    private let panel = SwitcherPanel()
    private lazy var keyboard = KeyboardInput { [weak self] event in self?.handle(event) }

    func start() {
        tracker.start()
        keyboard.start()
    }

    private func handle(_ event: SwitcherEvent) {
        let previous = switcher.state
        // The only final effect so far is Cancel, which leaves focus untouched.
        _ = switcher.handle(event, desktop: tracker.snapshot())
        // Re-showing an unchanged state would move the panel to the pointer's current display.
        guard switcher.state != previous else { return }
        switch switcher.state {
        case .closed:
            panel.hide()
        case .open(let displayed):
            panel.show(displayed, icon: tracker.icon(for:))
        }
    }
}
