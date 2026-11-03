import BackgroundAdapters
import Foundation
import SwitcherCore

// Turns native ⌘Tab and ⌘` back on when Downtab could not: after a forced kill or a crash.
// `--status` only reads, changing nothing.

private func say(_ line: String) {
    FileHandle.standardOutput.write(Data((line + "\n").utf8))
}

private func describe(_ enabled: Bool?) -> String {
    enabled.map { $0 ? "on" : "off" } ?? "unknown"
}

private func describe(_ binding: (keyCode: Int, modifierFlags: UInt64)?) -> String {
    binding.map { "keyCode=\($0.keyCode) modifiers=0x\(String($0.modifierFlags, radix: 16))" } ?? "binding unknown"
}

let hotKeys = WindowServerSymbolicHotKeys()
let statusOnly = CommandLine.arguments.dropFirst().contains("--status")
var failed = false

for native in NativeShortcut.allCases {
    for id in native.symbolicHotKeyIDs {
        let before = hotKeys.isEnabled(id)
        let prefix = "\(native) id=\(id) \(describe(hotKeys.binding(of: id))):"
        if statusOnly {
            say("\(prefix) \(describe(before))")
            continue
        }
        let changed = hotKeys.setEnabled(id, true)
        let after = hotKeys.isEnabled(id)
        if !changed || after == false { failed = true }
        say("\(prefix) \(describe(before)) -> \(describe(after))\(changed ? "" : " (refused)")")
    }
}

if statusOnly {
    exit(0)
}
say(failed ? "restore failed: see the lines above" : "restore ok: native ⌘Tab and ⌘` are on")
exit(failed ? 1 : 0)
