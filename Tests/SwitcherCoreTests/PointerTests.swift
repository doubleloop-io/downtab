import SwitcherCore
import Testing

// Hover

@Test func hoveringAnAppSelectsItAtAppLevel() {
    let desktop = DesktopSnapshot.with(mru: ["Mail", "Safari", "Notes"])
    var switcher = opened(on: desktop)

    switcher.handle(.pointer(.entered(.app(2))), desktop: desktop)

    #expect(switcher.state.selectedName == "Notes")
    #expect(switcher.state.isAtAppLevel)
}

@Test func hoveringAnotherAppAtWindowLevelClosesTheWindowList() {
    var (switcher, desktop) = atWindowLevel(on: [
        .regular("Safari", windows: [.window("S1"), .window("S2")]),
        .regular("Notes", windows: [.window("N1"), .window("N2")]),
    ])

    switcher.handle(.pointer(.entered(.app(2))), desktop: desktop)

    #expect(switcher.state.selectedName == "Notes")
    #expect(switcher.state.isAtAppLevel)
}

@Test func hoveringTheAppWhoseWindowListIsOpenChangesNothing() {
    var (switcher, desktop) = atWindowLevel(on: [.regular("Safari", windows: [.window("S1"), .window("S2")])])
    switcher.handle(.downPressed, desktop: desktop)
    let before = switcher.state

    switcher.handle(.pointer(.entered(.app(1))), desktop: desktop)

    #expect(switcher.state == before)
}

@Test func hoveringAWindowSelectsIt() {
    let safari = DesktopApp.regular("Safari", windows: [.window("S1"), .window("S2"), .window("S3")])
    var (switcher, desktop) = atWindowLevel(on: [safari])

    switcher.handle(.pointer(.entered(.window(2))), desktop: desktop)

    #expect(switcher.state.selectedWindowTitle == "S3")
}

@Test func hoveringAWindowAtAppLevelChangesNothing() {
    var (switcher, desktop) = openedOn(.regular("Safari", windows: [.window("S1"), .window("S2")]))
    let before = switcher.state

    switcher.handle(.pointer(.entered(.window(1))), desktop: desktop)

    #expect(switcher.state == before)
}

@Test(arguments: [
    PointerEvent.entered(.app(0)), .clicked(.app(0)), .clickedOutside, .scrolled(.down, over: .app(0)),
])
func pointerWhileClosedLeavesTheSwitcherClosed(pointer: PointerEvent) {
    var switcher = Switcher()

    let effect = switcher.handle(.pointer(pointer), desktop: .with(mru: ["Mail", "Safari"]))

    #expect(switcher.state == .closed)
    #expect(effect == nil)
}

// Click

@Test func clickingAnAppWithoutAWindowCountBadgeConfirmsIt() {
    let desktop = DesktopSnapshot.with(mru: ["Mail", "Safari", "Notes"])
    var switcher = opened(on: desktop)

    let effect = switcher.handle(.pointer(.clicked(.app(2))), desktop: desktop)

    #expect(effect == .activateApp(desktop.app(named: "Notes")))
    #expect(switcher.state == .closed)
}

@Test func clickingAnAppWithAWindowCountBadgeOpensItsWindowListOnTheFirstWindow() {
    let desktop = DesktopSnapshot.with(apps: [
        .regular("Frontmost"), .regular("Mail"), .regular("Safari", windows: [.window("S1"), .window("S2")]),
    ])
    var switcher = opened(on: desktop)

    let effect = switcher.handle(.pointer(.clicked(.app(2))), desktop: desktop)

    #expect(effect == nil)
    #expect(switcher.state.selectedName == "Safari")
    #expect(switcher.state.windowListTitles == ["S1", "S2"])
    #expect(switcher.state.selectedWindowTitle == "S1")
}

@Test func clickingTheFrontmostAppOpensItsWindowListOnTheWindowBehindLikeDown() {
    let desktop = DesktopSnapshot.with(apps: [
        .regular("Frontmost", windows: [.window("Current"), .window("Behind")]), .regular("Safari"),
    ])
    var switcher = opened(on: desktop)

    switcher.handle(.pointer(.clicked(.app(0))), desktop: desktop)

    #expect(switcher.state.selectedWindowTitle == "Behind")
}

@Test func clickingTheAppWhoseWindowListIsOpenKeepsTheSelectedWindow() {
    var (switcher, desktop) = atWindowLevel(on: [.regular("Safari", windows: [.window("S1"), .window("S2")])])
    switcher.handle(.downPressed, desktop: desktop)

    let effect = switcher.handle(.pointer(.clicked(.app(1))), desktop: desktop)

    #expect(effect == nil)
    #expect(switcher.state.selectedWindowTitle == "S2")
}

@Test func clickingAWindowConfirmsIt() throws {
    let second = DesktopWindow.window("S2")
    var (switcher, desktop) = atWindowLevel(on: [.regular("Safari", windows: [.window("S1"), second])])

    let effect = switcher.handle(.pointer(.clicked(.window(1))), desktop: desktop)

    #expect(effect == .bringWindowToFront(try #require(second.id), of: desktop.app(named: "Safari")))
    #expect(switcher.state == .closed)
}

@Test func clickingAWindowAtAppLevelChangesNothing() {
    var (switcher, desktop) = openedOn(.regular("Safari", windows: [.window("S1"), .window("S2")]))
    let before = switcher.state

    let effect = switcher.handle(.pointer(.clicked(.window(0))), desktop: desktop)

    #expect(effect == nil)
    #expect(switcher.state == before)
}

@Test func clickingOutsideCancels() {
    var (switcher, desktop) = atWindowLevel(on: [.regular("Safari", windows: [.window("S1"), .window("S2")])])

    let effect = switcher.handle(.pointer(.clickedOutside), desktop: desktop)

    #expect(effect == .noChange)
    #expect(switcher.state == .closed)
}

@Test func releasingTheModifierConfirmsTheSelectionMadeWithThePointer() throws {
    let second = DesktopWindow.window("S2")
    var (switcher, desktop) = atWindowLevel(on: [.regular("Safari", windows: [.window("S1"), second])])
    switcher.handle(.pointer(.entered(.window(1))), desktop: desktop)

    let effect = switcher.handle(.modifierReleased, desktop: desktop)

    #expect(effect == .bringWindowToFront(try #require(second.id), of: desktop.app(named: "Safari")))
}

// Scroll

@Test func scrollingDownOverAnAppSelectsItAndOpensItsWindowList() {
    let desktop = DesktopSnapshot.with(apps: [
        .regular("Frontmost"), .regular("Mail"), .regular("Safari", windows: [.window("S1"), .window("S2")]),
    ])
    var switcher = opened(on: desktop)

    switcher.handle(.pointer(.scrolled(.down, over: .app(2))), desktop: desktop)

    #expect(switcher.state.selectedName == "Safari")
    #expect(switcher.state.selectedWindowTitle == "S1")
}

@Test func scrollingUpOverAnAppSelectsItAtAppLevel() {
    let desktop = DesktopSnapshot.with(apps: [
        .regular("Frontmost"), .regular("Mail"), .regular("Safari", windows: [.window("S1"), .window("S2")]),
    ])
    var switcher = opened(on: desktop)

    switcher.handle(.pointer(.scrolled(.up, over: .app(2))), desktop: desktop)

    #expect(switcher.state.selectedName == "Safari")
    #expect(switcher.state.isAtAppLevel)
}

@Test(arguments: [ScrollDirection.down, .up])
func scrollingOverAnAppWithoutAWindowListOnlySelectsIt(direction: ScrollDirection) {
    let desktop = DesktopSnapshot.with(mru: ["Mail", "Safari", "Notes"])
    var switcher = opened(on: desktop)

    switcher.handle(.pointer(.scrolled(direction, over: .app(2))), desktop: desktop)

    #expect(switcher.state.selectedName == "Notes")
    #expect(switcher.state.isAtAppLevel)
}

@Test func scrollingDownAtWindowLevelStopsAtTheLastWindow() {
    var (switcher, desktop) = atWindowLevel(on: [.regular("Safari", windows: [.window("S1"), .window("S2")])])

    switcher.handle(.pointer(.scrolled(.down, over: .window(0))), desktop: desktop)
    switcher.handle(.pointer(.scrolled(.down, over: .window(1))), desktop: desktop)

    #expect(switcher.state.selectedWindowTitle == "S2")
}

@Test func scrollingUpFromTheFirstWindowGoesBackToAppLevelOnThatApp() {
    var (switcher, desktop) = atWindowLevel(on: [.regular("Safari", windows: [.window("S1"), .window("S2")])])

    switcher.handle(.pointer(.scrolled(.up, over: .window(0))), desktop: desktop)

    #expect(switcher.state.selectedName == "Safari")
    #expect(switcher.state.isAtAppLevel)
}

@Test func scrollingOverTheIconOfTheOpenWindowListWalksTheList() {
    var (switcher, desktop) = atWindowLevel(on: [.regular("Safari", windows: [.window("S1"), .window("S2")])])

    switcher.handle(.pointer(.scrolled(.down, over: .app(1))), desktop: desktop)

    #expect(switcher.state.selectedWindowTitle == "S2")
}

@Test func scrollingBetweenItemsWalksTheOpenWindowList() {
    var (switcher, desktop) = atWindowLevel(on: [.regular("Safari", windows: [.window("S1"), .window("S2")])])

    switcher.handle(.pointer(.scrolled(.down, over: nil)), desktop: desktop)

    #expect(switcher.state.selectedWindowTitle == "S2")
}

@Test func scrollingBetweenItemsAtAppLevelChangesNothing() {
    var (switcher, desktop) = openedOn(.regular("Safari", windows: [.window("S1"), .window("S2")]))
    let before = switcher.state

    switcher.handle(.pointer(.scrolled(.down, over: nil)), desktop: desktop)

    #expect(switcher.state == before)
}
