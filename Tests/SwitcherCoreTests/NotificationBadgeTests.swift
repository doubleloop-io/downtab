import SwitcherCore
import Testing

@Test func appWithADockBadgeShowsItsNotificationBadge() {
    let desktop = DesktopSnapshot.with(apps: [.regular("Slack", notificationBadge: "3")])

    #expect(opened(on: desktop).state.notificationBadge(of: "Slack") == "3")
}

@Test func appWithoutADockBadgeShowsNoNotificationBadge() {
    let desktop = DesktopSnapshot.with(apps: [.regular("Safari")])

    #expect(opened(on: desktop).state.notificationBadge(of: "Safari") == nil)
}

@Test func emptyDockBadgeShowsNoNotificationBadge() {
    let desktop = DesktopSnapshot.with(apps: [.regular("Mail", notificationBadge: "")])

    #expect(opened(on: desktop).state.notificationBadge(of: "Mail") == nil)
}

@Test func nonNumericDockBadgeIsShownAsIs() {
    let desktop = DesktopSnapshot.with(apps: [.regular("Slack", notificationBadge: "•")])

    #expect(opened(on: desktop).state.notificationBadge(of: "Slack") == "•")
}

@Test func appFromAFullScreenSpaceKeepsItsNotificationBadge() {
    let desktop = DesktopSnapshot.with(
        apps: [.regular("Notion", notificationBadge: "62")], isActiveSpaceFullScreen: true)

    #expect(opened(on: desktop).state.notificationBadge(of: "Notion") == "62")
}
