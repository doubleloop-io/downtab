import SwitcherCore
import Testing

@Test func windowsFollowTheOnScreenOrder() throws {
    let front = DesktopWindow.window("front")
    let back = DesktopWindow.window("back")
    let ranks = [try #require(front.id): 0, try #require(back.id): 1]

    let ordered = [back, front].orderedFrontToBack(onScreenRanks: ranks)

    #expect(ordered == [front, back])
}

@Test func windowsOffScreenFollowTheOnScreenOnesInTheirPreviousOrder() throws {
    let onScreen = DesktopWindow.window("on screen")
    let minimized = DesktopWindow.window("minimized", isMinimized: true)
    let otherSpace = DesktopWindow.window("other Space", in: [2])
    let ranks = [try #require(onScreen.id): 0]

    let ordered = [minimized, otherSpace, onScreen].orderedFrontToBack(onScreenRanks: ranks)

    #expect(ordered == [onScreen, minimized, otherSpace])
}

@Test func windowsWithNoIDFollowTheRankedOnes() throws {
    let unidentified = DesktopWindow.listed(role: "AXWindow", subrole: "AXStandardWindow", hasID: false)
    let ranked = DesktopWindow.window()
    let ranks = [try #require(ranked.id): 0]

    let ordered = [unidentified, ranked].orderedFrontToBack(onScreenRanks: ranks)

    #expect(ordered == [ranked, unidentified])
}
