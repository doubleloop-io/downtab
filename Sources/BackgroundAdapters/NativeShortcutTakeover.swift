public import SwitcherCore
import Synchronization

/// Turns native ⌘Tab and ⌘` off while Downtab's shortcuts take their place, and back on afterwards.
/// Sendable: termination signals restore from another thread.
public final class NativeShortcutTakeover: Sendable {
    private let hotKeys: any SymbolicHotKeySwitch
    /// Only the symbolic hot keys this instance switched off: one already off, by the user or a crashed run, is
    /// left as found.
    private let switchedOff = Mutex<Set<Int32>>([])

    public init(hotKeys: any SymbolicHotKeySwitch = WindowServerSymbolicHotKeys()) {
        self.hotKeys = hotKeys
    }

    /// Leaves exactly these native shortcuts off: turns them off, and back on any this instance turned off before.
    public func turnOff(exactly natives: Set<NativeShortcut>) {
        let wanted = Set(natives.flatMap(\.symbolicHotKeyIDs))
        switchedOff.withLock { switchedOff in
            for id in switchedOff.subtracting(wanted) where hotKeys.setEnabled(id, true) {
                switchedOff.remove(id)
            }
            for id in wanted.subtracting(switchedOff) where hotKeys.isEnabled(id) != false {
                if hotKeys.setEnabled(id, false) { switchedOff.insert(id) }
            }
        }
    }

    /// Turns back on every native shortcut this instance turned off.
    public func restore() {
        turnOff(exactly: [])
    }
}
