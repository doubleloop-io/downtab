import AppKit
import SwitcherCore

final class SwitcherController {
    private var switcher = Switcher()
    private let tracker = DesktopTracker()
    private let panel = SwitcherPanel()
    private let focuser = WindowFocuser()
    private lazy var keyboard = KeyboardInput { [weak self] event in self?.handle(event) }

    func start() {
        tracker.start()
        keyboard.start()
    }

    private func handle(_ event: SwitcherEvent) {
        let previous = switcher.state
        let effect = switcher.handle(event, desktop: tracker.snapshot())
        // Re-showing an unchanged state would move the panel to the pointer's current display.
        if switcher.state != previous {
            render()
        }
        if let effect {
            Task { [focuser] in await focuser.perform(effect) }
        }
    }

    private func render() {
        switch switcher.state {
        case .closed:
            panel.hide()
        case .open(let displayed):
            panel.show(displayed, icon: tracker.icon(for:))
        }
    }
}
