import BackgroundAdapters
import SwitcherCore
import Synchronization
import Testing

/// Symbolic hot keys in memory, all on unless a test says otherwise.
private final class FakeSymbolicHotKeys: SymbolicHotKeySwitch {
    private let state: Mutex<[Int32: Bool]>

    init(off: Set<Int32> = []) {
        state = Mutex(Dictionary(uniqueKeysWithValues: off.map { ($0, false) }))
    }

    func isEnabled(_ id: Int32) -> Bool? {
        state.withLock { $0[id] ?? true }
    }

    func setEnabled(_ id: Int32, _ enabled: Bool) -> Bool {
        state.withLock { $0[id] = enabled }
        return true
    }

    func enabled(_ native: NativeShortcut) -> Bool {
        native.symbolicHotKeyIDs.allSatisfy { isEnabled($0) == true }
    }

    func disabled(_ native: NativeShortcut) -> Bool {
        native.symbolicHotKeyIDs.allSatisfy { isEnabled($0) == false }
    }
}

@Test func takingOverCommandTabTurnsNativeCommandTabAndCommandShiftTabOff() {
    let hotKeys = FakeSymbolicHotKeys()
    let takeover = NativeShortcutTakeover(hotKeys: hotKeys)

    takeover.turnOff(exactly: [.commandTab])

    #expect(hotKeys.disabled(.commandTab))
    #expect(hotKeys.enabled(.commandGrave))
}

@Test func restoringTurnsBackOnEveryNativeShortcutTakenOver() {
    let hotKeys = FakeSymbolicHotKeys()
    let takeover = NativeShortcutTakeover(hotKeys: hotKeys)
    takeover.turnOff(exactly: [.commandTab, .commandGrave])

    takeover.restore()

    #expect(hotKeys.enabled(.commandTab))
    #expect(hotKeys.enabled(.commandGrave))
}

@Test func aNativeShortcutNoLongerTakenOverIsTurnedBackOn() {
    let hotKeys = FakeSymbolicHotKeys()
    let takeover = NativeShortcutTakeover(hotKeys: hotKeys)
    takeover.turnOff(exactly: [.commandTab, .commandGrave])

    takeover.turnOff(exactly: [.commandGrave])

    #expect(hotKeys.enabled(.commandTab))
    #expect(hotKeys.disabled(.commandGrave))
}

@Test func takingOverTheSameNativeShortcutAgainStillRestoresIt() {
    let hotKeys = FakeSymbolicHotKeys()
    let takeover = NativeShortcutTakeover(hotKeys: hotKeys)
    takeover.turnOff(exactly: [.commandTab])
    takeover.turnOff(exactly: [.commandTab])

    takeover.restore()

    #expect(hotKeys.enabled(.commandTab))
}

@Test func aNativeShortcutAlreadyOffWhenTakenOverIsTurnedOnByRestore() {
    let hotKeys = FakeSymbolicHotKeys(off: Set(NativeShortcut.commandTab.symbolicHotKeyIDs))
    let takeover = NativeShortcutTakeover(hotKeys: hotKeys)
    takeover.turnOff(exactly: [.commandTab])

    takeover.restore()

    #expect(hotKeys.enabled(.commandTab))
}
