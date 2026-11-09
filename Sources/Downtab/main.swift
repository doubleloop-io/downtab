import AppKit
import BackgroundAdapters
import SwitcherCore

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private let switcher = SwitcherController()
    private let permission = PermissionMonitor()
    private let takeover = NativeShortcutTakeover()
    private let terminationSignals = TerminationSignals()
    private lazy var shortcuts = ShortcutSettings(keyboard: switcher.keyboard, takeover: takeover)
    private lazy var preferences = PreferencesWindow(settings: shortcuts)
    private let permissionMissingItem = NSMenuItem(
        title: "Accessibility Permission Missing…", action: #selector(openPreferences), keyEquivalent: "")
    private let updateCheck = UpdateCheck()
    private let updateAvailableItem = NSMenuItem(title: "", action: #selector(openDownloadPage), keyEquivalent: "")

    func applicationDidFinishLaunching(_ notification: Notification) {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        let menu = NSMenu()
        permissionMissingItem.target = self
        menu.addItem(permissionMissingItem)
        updateAvailableItem.target = self
        updateAvailableItem.isHidden = true
        menu.addItem(updateAvailableItem)
        menu.addItem(withTitle: "About Downtab", action: #selector(openAbout), keyEquivalent: "").target = self
        menu.addItem(withTitle: "Preferences…", action: #selector(openPreferences), keyEquivalent: ",").target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit Downtab", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        item.menu = menu
        statusItem = item
        // Native ⌘Tab and ⌘` stay off after Downtab exits unless it turns them back on.
        terminationSignals.install(cleanUp: takeover.restore)
        switcher.start()
        LaunchAtLogin().applyStored()
        permission.start { [weak self] change in self?.apply(change) }
        updateCheck.start { [weak self] newer in self?.showUpdateAvailable(newer) }
        // Guided setup: the Preferences show the missing permission highlighted.
        if !permission.isGranted {
            preferences.open()
        }
    }

    private func apply(_ change: PermissionWatch.Change) {
        let isGranted = change == .granted
        if isGranted {
            switcher.keyboard.startEventTaps()
            shortcuts.enable()
        } else {
            shortcuts.disable()
        }
        statusItem?.button?.image = NSImage(
            systemSymbolName: isGranted ? "rectangle.stack" : "exclamationmark.triangle",
            accessibilityDescription: isGranted ? "Downtab" : "Downtab: Accessibility permission missing"
        )
        permissionMissingItem.isHidden = isGranted
        preferences.showPermission(isGranted: isGranted)
    }

    private func showUpdateAvailable(_ newerRelease: ReleaseVersion?) {
        updateAvailableItem.isHidden = newerRelease == nil
        if let newerRelease {
            updateAvailableItem.title = "Update Available: \(newerRelease)…"
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        takeover.restore()
    }

    @objc private func openAbout() {
        // An agent app is not active when its menu bar menu is used: without activating, the panel opens behind other windows.
        NSApp.activate()
        NSApp.orderFrontStandardAboutPanel(nil)
    }

    @objc private func openPreferences() {
        preferences.open()
    }

    @objc private func openDownloadPage() {
        guard let page = UpdateCheck.downloadPage else { return }
        NSWorkspace.shared.open(page)
    }
}

let app = NSApplication.shared
// LSUIElement already hides the Dock icon in the bundle; this also covers `swift run`.
app.setActivationPolicy(.accessory)
let delegate = AppDelegate()
app.delegate = delegate
app.run()
