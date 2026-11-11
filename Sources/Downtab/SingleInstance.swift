import AppKit
import os

/// Only one Downtab runs at a time, whatever its version or location: switching copies means quitting the running one.
enum SingleInstance {
    private static let logger = Logger(subsystem: "io.doubleloop.downtab", category: "instance")

    /// Must run before anything touches the event taps, the native shortcuts or the login item: any `SMAppService`
    /// call moves the login item to this copy, and exiting would turn native ⌘Tab back on under the running instance.
    static func exitIfAnotherIsRunning() {
        guard let running = earlierInstance() else { return }
        let version =
            running.bundleURL.flatMap(Bundle.init(url:))?
            .object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        let path = running.bundleURL?.path ?? "an unknown location"
        logger.notice(
            "another instance is running (pid=\(running.processIdentifier), path=\(path, privacy: .public)): exiting")
        showAlreadyRunning(version: version, path: path)
        exit(0)
    }

    /// Two copies launched together (at login and by hand) must not both exit: the later one gives way.
    private static func earlierInstance() -> NSRunningApplication? {
        let current = NSRunningApplication.current
        guard let bundleID = Bundle.main.bundleIdentifier else { return nil }
        return NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).first { other in
            guard other.processIdentifier != current.processIdentifier, !other.isTerminated else { return false }
            guard let otherLaunch = other.launchDate, let currentLaunch = current.launchDate else { return true }
            return otherLaunch < currentLaunch
                || (otherLaunch == currentLaunch && other.processIdentifier < current.processIdentifier)
        }
    }

    private static func showAlreadyRunning(version: String?, path: String) {
        let alert = NSAlert()
        alert.messageText = "Downtab is already running"
        alert.informativeText = """
            Downtab\(version.map { " \($0)" } ?? "") is running from \(path).
            To open this copy, quit the running one from its menu bar icon first.
            """
        alert.addButton(withTitle: "OK")
        NSApp.activate()
        alert.runModal()
    }
}
