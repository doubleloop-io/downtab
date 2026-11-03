import SwitcherCore
import Testing

@Test(arguments: [(true, PermissionWatch.Change.granted), (false, .revoked)])
func theFirstReadingReportsThePermissionAsChanged(isGranted: Bool, change: PermissionWatch.Change) {
    var watch = PermissionWatch()

    #expect(watch.observe(isGranted: isGranted) == change)
}

@Test(arguments: [true, false])
func anUnchangedReadingReportsNothing(isGranted: Bool) {
    var watch = PermissionWatch()
    _ = watch.observe(isGranted: isGranted)

    #expect(watch.observe(isGranted: isGranted) == nil)
}

@Test func grantingAfterLaunchWithoutPermissionReportsTheGrant() {
    var watch = PermissionWatch()
    _ = watch.observe(isGranted: false)

    #expect(watch.observe(isGranted: true) == .granted)
}

@Test func revokingWhileRunningReportsTheRevocation() {
    var watch = PermissionWatch()
    _ = watch.observe(isGranted: true)

    #expect(watch.observe(isGranted: false) == .revoked)
}
