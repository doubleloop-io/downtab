import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private let switcher = SwitcherController()
    private lazy var shortcuts = ShortcutSettings(keyboard: switcher.keyboard)
    private lazy var preferences = PreferencesWindow(settings: shortcuts)

    func applicationDidFinishLaunching(_ notification: Notification) {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.image = NSImage(systemSymbolName: "rectangle.stack", accessibilityDescription: "Downtab")
        let menu = NSMenu()
        menu.addItem(withTitle: "Preferences…", action: #selector(openPreferences), keyEquivalent: ",").target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit Downtab", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        item.menu = menu
        statusItem = item
        switcher.start(shortcuts: shortcuts.current)
    }

    @objc private func openPreferences() {
        preferences.open()
    }
}

let app = NSApplication.shared
// LSUIElement already hides the Dock icon in the bundle; this also covers `swift run`.
app.setActivationPolicy(.accessory)
let delegate = AppDelegate()
app.delegate = delegate
app.run()
