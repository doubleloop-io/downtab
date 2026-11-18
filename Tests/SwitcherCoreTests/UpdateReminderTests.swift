import Foundation
import SwitcherCore
import Testing

private let day: TimeInterval = 24 * 60 * 60
private let start = Date(timeIntervalSinceReferenceDate: 0)

@Test func noReminderBeforeAnyUpdateIsSignalled() {
    #expect(UpdateReminder().isDue(at: start.addingTimeInterval(100 * day)) == false)
}

@Test func theReminderIsDueSevenDaysAfterTheFirstSignal() {
    var reminder = UpdateReminder()

    reminder.signalled(build: 2, at: start)

    #expect(reminder.isDue(at: start.addingTimeInterval(7 * day - 1)) == false)
    #expect(reminder.isDue(at: start.addingTimeInterval(7 * day)))
}

@Test func aNewerUpdateKeepsTheDateOfTheFirstSignal() {
    var reminder = UpdateReminder()
    reminder.signalled(build: 2, at: start)

    reminder.signalled(build: 3, at: start.addingTimeInterval(5 * day))

    #expect(reminder.firstSignalled == start)
    #expect(reminder.signalledBuild == 3)
    #expect(reminder.isDue(at: start.addingTimeInterval(7 * day)))
}

@Test func afterARemindingTheNextOneIsDueSevenDaysLater() {
    var reminder = UpdateReminder()
    reminder.signalled(build: 2, at: start)
    let shown = start.addingTimeInterval(8 * day)

    reminder.reminded(at: shown)

    #expect(reminder.isDue(at: shown.addingTimeInterval(7 * day - 1)) == false)
    #expect(reminder.isDue(at: shown.addingTimeInterval(7 * day)))
}

@Test(arguments: [2, 3])
func launchingTheSignalledBuildOrALaterOneForgetsTheUpdate(runningBuild: Int) {
    var reminder = UpdateReminder()
    reminder.signalled(build: 2, at: start)
    reminder.reminded(at: start.addingTimeInterval(8 * day))

    reminder.launched(runningBuild: runningBuild)

    #expect(reminder == UpdateReminder())
}

@Test func launchingAnOlderBuildKeepsTheUpdatePending() {
    var reminder = UpdateReminder()
    reminder.signalled(build: 2, at: start)

    reminder.launched(runningBuild: 1)

    #expect(reminder.firstSignalled == start)
}
