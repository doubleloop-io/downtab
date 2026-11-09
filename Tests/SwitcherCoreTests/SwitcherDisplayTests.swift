import SwitcherCore
import Testing

private let menuBarDisplay = ScreenRect(x: 0, y: 0, width: 1440, height: 900)
private let rightDisplay = ScreenRect(x: 1440, y: 0, width: 1920, height: 1080)

@Test func pointerPlacementPicksTheDisplayUnderThePointer() {
    let index = SwitcherDisplay.index(
        for: .pointerDisplay, displays: [menuBarDisplay, rightDisplay], pointer: ScreenPoint(x: 2000, y: 500),
        focusedWindow: nil)

    #expect(index == 1)
}

@Test func pointerOutsideEveryDisplayFallsBackToTheMenuBarDisplay() {
    let index = SwitcherDisplay.index(
        for: .pointerDisplay, displays: [menuBarDisplay, rightDisplay], pointer: ScreenPoint(x: -50, y: 500),
        focusedWindow: nil)

    #expect(index == 0)
}

@Test func menuBarPlacementPicksTheMenuBarDisplayWhereverThePointerIs() {
    let index = SwitcherDisplay.index(
        for: .menuBarDisplay, displays: [menuBarDisplay, rightDisplay], pointer: ScreenPoint(x: 2000, y: 500),
        focusedWindow: nil)

    #expect(index == 0)
}

@Test func focusedWindowPlacementPicksTheDisplayHoldingTheFocusedWindow() {
    let windowOnRightDisplay = ScreenRect(x: 1600, y: 100, width: 800, height: 600)

    let index = SwitcherDisplay.index(
        for: .focusedWindowDisplay, displays: [menuBarDisplay, rightDisplay], pointer: ScreenPoint(x: 100, y: 100),
        focusedWindow: windowOnRightDisplay)

    #expect(index == 1)
}

@Test func focusedWindowBoundsAreReadFromTheTopOfTheMenuBarDisplay() {
    let displayAbove = ScreenRect(x: 0, y: 900, width: 1920, height: 1080)
    // Window-server bounds grow downwards from the menu bar display's top edge: negative y is above it.
    let windowOnDisplayAbove = ScreenRect(x: 100, y: -800, width: 600, height: 400)

    let index = SwitcherDisplay.index(
        for: .focusedWindowDisplay, displays: [menuBarDisplay, displayAbove], pointer: ScreenPoint(x: 100, y: 100),
        focusedWindow: windowOnDisplayAbove)

    #expect(index == 1)
}

@Test func focusedWindowAcrossDisplaysPicksTheDisplayHoldingMostOfIt() {
    // 440×50 points on the menu bar display, 260×200 on the taller right display.
    let windowAcrossDisplays = ScreenRect(x: 1000, y: -150, width: 700, height: 200)

    let index = SwitcherDisplay.index(
        for: .focusedWindowDisplay, displays: [menuBarDisplay, rightDisplay], pointer: ScreenPoint(x: 100, y: 100),
        focusedWindow: windowAcrossDisplays)

    #expect(index == 1)
}

@Test func focusedWindowPlacementWithoutAFocusedWindowFallsBackToTheMenuBarDisplay() {
    let index = SwitcherDisplay.index(
        for: .focusedWindowDisplay, displays: [menuBarDisplay, rightDisplay], pointer: ScreenPoint(x: 2000, y: 500),
        focusedWindow: nil)

    #expect(index == 0)
}

@Test func pointerOnTheTopEdgeOfADisplayIsOnThatDisplay() {
    // AppKit reports the pointer on a display's topmost row at the display's top edge.
    let index = SwitcherDisplay.index(
        for: .pointerDisplay, displays: [menuBarDisplay, rightDisplay], pointer: ScreenPoint(x: 2000, y: 1080),
        focusedWindow: nil)

    #expect(index == 1)
}

@Test func focusedWindowOnNoDisplayFallsBackToTheMenuBarDisplay() {
    let windowOffEveryDisplay = ScreenRect(x: 5000, y: 0, width: 800, height: 600)

    let index = SwitcherDisplay.index(
        for: .focusedWindowDisplay, displays: [menuBarDisplay, rightDisplay], pointer: ScreenPoint(x: 2000, y: 500),
        focusedWindow: windowOffEveryDisplay)

    #expect(index == 0)
}
