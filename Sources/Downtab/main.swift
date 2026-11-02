import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private let switcher = SwitcherController()

    func applicationDidFinishLaunching(_ notification: Notification) {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.image = NSImage(systemSymbolName: "rectangle.stack", accessibilityDescription: "Downtab")
        let menu = NSMenu()
        menu.addItem(withTitle: "Quit Downtab", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        item.menu = menu
        statusItem = item
        switcher.start()
    }
}

let app = NSApplication.shared
// LSUIElement already hides the Dock icon in the bundle; this also covers `swift run`.
app.setActivationPolicy(.accessory)
let delegate = AppDelegate()
app.delegate = delegate
app.run()
