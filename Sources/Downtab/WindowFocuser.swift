import AppKit
import SwitcherCore
import os

/// Executes the final effect off the main thread, so a slow target app never stalls the Switcher.
/// An actor, so effects never overlap.
actor WindowFocuser {
    private let logger = Logger(subsystem: "local.downtab", category: "focus")

    func perform(_ effect: FinalEffect) {
        switch effect {
        case .noChange:
            break
        case .activateApp(let id):
            activate(id)
        }
    }

    private func activate(_ id: AppID) {
        guard let app = NSRunningApplication(processIdentifier: id.processIdentifier) else {
            logger.error("activate pid=\(id.processIdentifier): app no longer running")
            return
        }
        // Like the native switcher: the whole app comes forward, unhidden if needed.
        let activated = app.activate()
        logger.info("activate pid=\(id.processIdentifier) ok=\(activated)")
    }
}
