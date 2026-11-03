public import SwitcherCore
import Synchronization

/// Sendable: termination signals restore from another thread.
public final class NativeShortcutTakeover: Sendable {
    private let hotKeys: any SymbolicHotKeySwitch
    private let switchedOff = Mutex<Set<Int32>>([])

    public init(hotKeys: any SymbolicHotKeySwitch = WindowServerSymbolicHotKeys()) {
        self.hotKeys = hotKeys
    }

    /// A native shortcut already off counts as switched off here too: a crashed or force-killed run leaves the ones
    /// it took over off, and Downtab cannot tell them from ones the user turned off, so it restores both.
    public func turnOff(exactly natives: Set<NativeShortcut>) {
        let wanted = Set(natives.flatMap(\.symbolicHotKeyIDs))
        switchedOff.withLock { switchedOff in
            for id in switchedOff.subtracting(wanted) where hotKeys.setEnabled(id, true) {
                switchedOff.remove(id)
            }
            for id in wanted.subtracting(switchedOff)
            where hotKeys.isEnabled(id) == false || hotKeys.setEnabled(id, false) {
                switchedOff.insert(id)
            }
        }
    }

    public func restore() {
        turnOff(exactly: [])
    }
}
