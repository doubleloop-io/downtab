import SwitcherCore
import Testing

@Test func quickAppShortcutConfirmsWithoutEverShowingTheSwitcher() {
    let desktop = DesktopSnapshot.with(mru: ["Notes", "Safari"])
    var switcher = Switcher()

    switcher.handle(.appShortcutPressed, desktop: desktop)
    let shownBeforeRelease = switcher.state.isVisible
    let effect = switcher.handle(.modifierReleased, desktop: desktop)

    #expect(!shownBeforeRelease)
    #expect(effect == .activateApp(desktop.app(named: "Safari")))
}

@Test func quickWindowShortcutConfirmsWithoutEverShowingTheSwitcher() throws {
    let behind = DesktopWindow.window("Behind")
    let desktop = DesktopSnapshot.with(apps: [.regular("Safari", windows: [.window("Current"), behind])])
    var switcher = Switcher()

    switcher.handle(.windowShortcutPressed, desktop: desktop)
    let shownBeforeRelease = switcher.state.isVisible
    let effect = switcher.handle(.modifierReleased, desktop: desktop)

    #expect(!shownBeforeRelease)
    #expect(effect == .bringWindowToFront(try #require(behind.id), of: desktop.app(named: "Safari")))
}

@Test func showDelayElapsedWhileOpenShowsTheSwitcher() {
    let desktop = DesktopSnapshot.with(mru: ["Notes", "Safari"])
    var switcher = opened(on: desktop)

    switcher.handle(.showDelayElapsed, desktop: desktop)

    #expect(switcher.state.isVisible)
    #expect(switcher.state.selectedName == "Safari")
}

@Test func movingTheSelectionOnceShownKeepsTheSwitcherVisible() {
    let desktop = DesktopSnapshot.with(mru: ["Notes", "Safari", "TextEdit"])
    var switcher = opened(on: desktop)
    switcher.handle(.showDelayElapsed, desktop: desktop)

    switcher.handle(.appShortcutPressed, desktop: desktop)

    #expect(switcher.state.isVisible)
    #expect(switcher.state.selectedName == "TextEdit")
}
