import SwitcherCore
import Testing

private let mail = AppID(processIdentifier: 1)
private let safari = AppID(processIdentifier: 2)
private let notes = AppID(processIdentifier: 3)
private let finder = AppID(processIdentifier: 4)

@Test func seedingOrdersAppsByTheirFrontmostWindowWithTheFrontmostAppFirst() {
    let order = MRUOrder(
        running: [mail, safari, notes, finder],
        windowOwnersFrontToBack: [safari, notes, safari, mail],
        frontmost: finder
    )

    #expect(order.apps == [finder, safari, notes, mail])
}

@Test func seedingPutsAppsWithNoOnScreenWindowAfterTheOthersInRunningOrder() {
    let order = MRUOrder(running: [mail, safari, notes], windowOwnersFrontToBack: [notes], frontmost: notes)

    #expect(order.apps == [notes, mail, safari])
}

@Test func seedingIgnoresWindowsOfProcessesThatAreNotTrackedApps() {
    let windowServer = AppID(processIdentifier: 99)

    let order = MRUOrder(running: [mail, safari], windowOwnersFrontToBack: [windowServer, safari], frontmost: nil)

    #expect(order.apps == [safari, mail])
}

@Test func activationMovesTheAppToTheFront() {
    var order = MRUOrder(running: [mail, safari, notes], windowOwnersFrontToBack: [], frontmost: nil)

    order.recordActivation(of: notes)

    #expect(order.apps == [notes, mail, safari])
}

@Test func launchedAppJoinsAsTheLeastRecentlyUsed() {
    var order = MRUOrder(running: [mail, safari], windowOwnersFrontToBack: [], frontmost: nil)

    order.recordLaunch(of: notes)

    #expect(order.apps == [mail, safari, notes])
}

@Test func launchOfAnAlreadyKnownAppKeepsItsPosition() {
    var order = MRUOrder(running: [mail, safari], windowOwnersFrontToBack: [], frontmost: nil)
    order.recordActivation(of: safari)

    order.recordLaunch(of: safari)

    #expect(order.apps == [safari, mail])
}

@Test func quitAppLeavesTheOrder() {
    var order = MRUOrder(running: [mail, safari, notes], windowOwnersFrontToBack: [], frontmost: nil)

    order.recordQuit(of: safari)

    #expect(order.apps == [mail, notes])
}
