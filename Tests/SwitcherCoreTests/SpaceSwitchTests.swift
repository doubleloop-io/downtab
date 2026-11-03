import SwitcherCore
import Testing

/// Confirms the app the Switcher opens on, behind a full-screen Frontmost app in Space 7.
private func confirmingFromFullScreen(_ app: DesktopApp) -> FinalEffect? {
    let fullScreen = DesktopApp.regular("Safari", windows: [.window(in: [7], isFullScreen: true)])
    let desktop = DesktopSnapshot.with(apps: [fullScreen, app], currentSpaces: [7], isActiveSpaceFullScreen: true)
    var switcher = opened(on: desktop)
    return switcher.handle(.modifierReleased, desktop: desktop)
}

@Test func confirmingAnAppWithWindowsOnlyInAnotherSpaceAlsoFrontsItsFrontmostWindow() {
    let front = DesktopWindow.unlisted(in: [1])
    let app = DesktopApp.regular("Miro", windows: [front, .unlisted(in: [1])])

    let effect = confirmingFromFullScreen(app)

    #expect(effect == .activateApp(app.id, frontingWindow: front.id))
}

@Test func confirmingAnAppWithAWindowInTheCurrentSpaceOnlyActivatesIt() {
    let app = DesktopApp.regular("Miro", windows: [.unlisted(in: [1]), .window(in: [7])])

    let effect = confirmingFromFullScreen(app)

    #expect(effect == .activateApp(app.id))
}

@Test(arguments: [
    [DesktopWindow](),
    [.listed(role: "AXWindow", subrole: "AXStandardWindow", in: [1], isMinimized: true)],
])
func confirmingAnAppWithNoWindowToFrontOnlyActivatesIt(windows: [DesktopWindow]) {
    let app = DesktopApp.regular("Miro", windows: windows)

    let effect = confirmingFromFullScreen(app)

    #expect(effect == .activateApp(app.id))
}

@Test func theFrontedWindowSkipsMinimizedAndServiceWindows() {
    let front = DesktopWindow.unlisted(in: [1])
    let app = DesktopApp.regular(
        "Miro",
        windows: [
            .listed(role: "AXWindow", subrole: "AXStandardWindow", in: [1], isMinimized: true),
            .unlisted(in: [1], size: WindowSize(width: 60, height: 40)),
            front,
        ])

    let effect = confirmingFromFullScreen(app)

    #expect(effect == .activateApp(app.id, frontingWindow: front.id))
}

@Test func confirmingAHiddenAppWithWindowsOnlyInAnotherSpaceAlsoFrontsItsFrontmostWindow() {
    let front = DesktopWindow.unlisted(in: [2])
    let app = DesktopApp.regular("Miro", isHidden: true, windows: [front])
    let desktop = DesktopSnapshot.with(apps: [.regular("Mail", windows: [.window(in: [1])]), app], currentSpaces: [1])
    var switcher = opened(on: desktop)

    let effect = switcher.handle(.modifierReleased, desktop: desktop)

    #expect(effect == .activateApp(app.id, frontingWindow: front.id))
}
