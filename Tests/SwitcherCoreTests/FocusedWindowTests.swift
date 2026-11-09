import SwitcherCore
import Testing

private let frontmostApp = AppID(processIdentifier: 1)
private let otherApp = AppID(processIdentifier: 2)

private func window(of owner: AppID, width: Double = 800, height: Double = 600, alpha: Double = 1) -> OnScreenWindow {
    OnScreenWindow(owner: owner, bounds: ScreenRect(x: 0, y: 0, width: width, height: height), alpha: alpha)
}

@Test func focusedWindowIsTheAppsFrontmostWindowOnScreen() {
    let front = window(of: frontmostApp, width: 900)
    let windowsFrontToBack = [window(of: otherApp), front, window(of: frontmostApp, width: 700)]

    #expect(windowsFrontToBack.focusedWindow(of: frontmostApp) == front)
}

@Test func transparentWindowsAreNotFocusedWindows() {
    let visible = window(of: frontmostApp)
    let windowsFrontToBack = [window(of: frontmostApp, alpha: 0), visible]

    #expect(windowsFrontToBack.focusedWindow(of: frontmostApp) == visible)
}

@Test(arguments: [(width: 99.0, height: 600.0), (width: 800.0, height: 49.0)])
func serviceWindowsSmallerThanARealWindowAreNotFocusedWindows(width: Double, height: Double) {
    let real = window(of: frontmostApp)
    let windowsFrontToBack = [window(of: frontmostApp, width: width, height: height), real]

    #expect(windowsFrontToBack.focusedWindow(of: frontmostApp) == real)
}
