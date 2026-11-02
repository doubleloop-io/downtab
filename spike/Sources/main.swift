import AppKit
import ApplicationServices
import Carbon

private func argument(_ name: String) -> String? {
    let arguments = CommandLine.arguments
    guard let index = arguments.firstIndex(of: name), arguments.indices.contains(index + 1) else { return nil }
    return arguments[index + 1]
}

// Off the main queue so the spike still exits if the main thread is stuck.
private func armTimeout(seconds: Int) {
    DispatchQueue.global().asyncAfter(deadline: .now() + .seconds(seconds)) {
        Log.write("timeout_exit seconds=\(seconds)")
        exit(0)
    }
}

private func logEnvironment() {
    let layout = TISCopyCurrentKeyboardLayoutInputSource()?.takeRetainedValue()
    let name = layout.flatMap { TISGetInputSourceProperty($0, kTISPropertyLocalizedName) }
        .map { Unmanaged<CFString>.fromOpaque($0).takeUnretainedValue() as String } ?? "?"
    let keyboardType = LMGetKbdType()
    let physical = KBGetLayoutType(Int16(keyboardType))
    Log.write("environment macos=\(ProcessInfo.processInfo.operatingSystemVersionString) layout=\"\(name)\" kbdType=\(keyboardType) physical=\(physical == kKeyboardISO ? "ISO" : physical == kKeyboardJIS ? "JIS" : "ANSI")")
}

let promptOption = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
guard AXIsProcessTrustedWithOptions([promptOption: true] as CFDictionary) else {
    Log.write("ERRORE: permesso Accessibility mancante. Concedilo ad DowntabSpike in Impostazioni > Privacy e sicurezza > Accessibilità, poi riavvia.")
    exit(1)
}

if CommandLine.arguments.contains("--list") {
    Inventory.writeReport()
    exit(0)
}

let timeoutSeconds = Int(argument("--timeout") ?? "") ?? 300
let strategy = FocusStrategy(rawValue: argument("--focus") ?? "") ?? .publicAPI
armTimeout(seconds: timeoutSeconds)
logEnvironment()
Log.write("start pid=\(getpid()) timeout=\(timeoutSeconds)s focus=\(strategy.rawValue)")

let application = NSApplication.shared
application.setActivationPolicy(.accessory)

let inventory = Inventory()
inventory.startRefreshing()
let switcher = Switcher(inventory: inventory, strategy: strategy)

Hotkeys.register { action, keyCode, pressedAt in
    switcher.handle(action, keyCode: keyCode, pressedAt: pressedAt)
}
guard OptionReleaseTap.start({ DispatchQueue.main.async { switcher.optionReleased() } }) else {
    Log.write("ERRORE: tapCreate fallito, rilascio di ⌥ non rilevabile")
    exit(1)
}
Log.write("ready: ⌥Tab, ⌥`, uscita ⌃⌥⇧Q")
application.run()
