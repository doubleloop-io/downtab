import BackgroundAdapters
import Foundation
import Synchronization
import Testing

@Test func answersReplaceThePreviousOnesAndKeysNoLongerAskedAreDropped() async {
    let query = TimeboxedQuery<String, Int>()
    _ = await query.run(["kept", "gone"], within: .seconds(5)) { _ in 1 }

    let result = await query.run(["kept", "new"], within: .seconds(5)) { key in key == "kept" ? 10 : 20 }

    #expect(result.answers == ["kept": 10, "new": 20])
    #expect(result.unanswered.isEmpty)
}

@Test func aQueryMissingTheDeadlineKeepsItsPreviousAnswerWithoutDelayingTheOthers() async {
    let query = TimeboxedQuery<String, Int>()
    _ = await query.run(["frozen"], within: .seconds(5)) { _ in 1 }
    let began = ContinuousClock.now

    let result = await query.run(["frozen", "responsive"], within: .milliseconds(100)) { key in
        if key == "frozen" { Thread.sleep(forTimeInterval: 5) }
        return 2
    }

    #expect(ContinuousClock.now - began < .seconds(2))
    #expect(result.answers == ["frozen": 1, "responsive": 2])
    #expect(result.unanswered == ["frozen"])
}

@Test func aFailedQueryKeepsItsPreviousAnswer() async {
    let query = TimeboxedQuery<String, Int>()
    _ = await query.run(["failing"], within: .seconds(5)) { _ in 1 }

    let result = await query.run(["failing"], within: .seconds(5)) { _ in nil }

    #expect(result.answers == ["failing": 1])
    #expect(result.unanswered == ["failing"])
}

@Test func aKeyWhoseQueryIsStillRunningIsNotAskedAgain() async {
    let query = TimeboxedQuery<String, Int>()
    let calls = Mutex(0)
    let ask: @Sendable (String) -> Int? = { _ in
        calls.withLock { $0 += 1 }
        Thread.sleep(forTimeInterval: 1)
        return 1
    }
    _ = await query.run(["slow"], within: .milliseconds(50), ask)

    _ = await query.run(["slow"], within: .milliseconds(50), ask)

    #expect(calls.withLock { $0 } == 1)
}

@Test func anAnswerArrivingAfterTheDeadlineIsTheAnswerOfTheNextRun() async throws {
    let query = TimeboxedQuery<String, Int>()
    let missed = await query.run(["slow"], within: .milliseconds(50)) { _ in
        Thread.sleep(forTimeInterval: 0.2)
        return 1
    }
    try await Task.sleep(for: .milliseconds(400))

    let result = await query.run(["slow"], within: .milliseconds(50)) { _ in
        Thread.sleep(forTimeInterval: 5)
        return 2
    }

    #expect(missed.answers.isEmpty)
    #expect(result.answers == ["slow": 1])
}

@Test func anAnswerArrivingDuringTheNextRunCountsAsThatRunsAnswer() async {
    let query = TimeboxedQuery<String, Int>()
    _ = await query.run(["slow"], within: .milliseconds(50)) { _ in
        Thread.sleep(forTimeInterval: 0.3)
        return 1
    }

    let result = await query.run(["slow"], within: .seconds(5)) { _ in 2 }

    #expect(result.answers == ["slow": 1])
    #expect(result.unanswered.isEmpty)
}
