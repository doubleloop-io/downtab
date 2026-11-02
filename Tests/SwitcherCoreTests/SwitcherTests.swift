import SwitcherCore
import Testing

@Test func newSwitcherIsClosed() {
    let switcher = Switcher()

    #expect(switcher.state == .closed)
}
