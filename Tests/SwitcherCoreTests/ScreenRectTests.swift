import SwitcherCore
import Testing

private let menuBarDisplay = ScreenRect(x: 0, y: 0, width: 1000, height: 800)

@Test func flippingMeasuresFromTheOtherEdgeOfTheMenuBarDisplay() {
    let appKit = ScreenRect(x: 100, y: 50, width: 200, height: 100)

    #expect(appKit.flipped(around: menuBarDisplay) == ScreenRect(x: 100, y: 650, width: 200, height: 100))
}

@Test func flippingTwiceGivesTheSameRect() {
    let rect = ScreenRect(x: -300, y: 900, width: 200, height: 100)

    #expect(rect.flipped(around: menuBarDisplay).flipped(around: menuBarDisplay) == rect)
}

@Test func aDisplayAboveTheMenuBarDisplayIsAboveItInTheWindowServerToo() {
    let above = ScreenRect(x: 0, y: 800, width: 1000, height: 600)

    #expect(above.flipped(around: menuBarDisplay) == ScreenRect(x: 0, y: -600, width: 1000, height: 600))
}
