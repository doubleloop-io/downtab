import BackgroundAdapters
import Foundation
import Testing

@Test func answersReplaceThePreviousOnesAndKeysNoLongerAskedAreDropped() async {
    let result = await TimeboxedQuery.run(
        ["kept", "new"], within: .seconds(5), previous: ["kept": 1, "gone": 2]
    ) { key in key == "kept" ? 10 : 20 }

    #expect(result.answers == ["kept": 10, "new": 20])
    #expect(result.unanswered.isEmpty)
}

@Test func aQueryMissingTheDeadlineKeepsItsPreviousAnswerWithoutDelayingTheOthers() async {
    let began = ContinuousClock.now

    let result = await TimeboxedQuery.run(
        ["frozen", "responsive"], within: .milliseconds(100), previous: ["frozen": 1]
    ) { key in
        if key == "frozen" { Thread.sleep(forTimeInterval: 5) }
        return 2
    }

    #expect(ContinuousClock.now - began < .seconds(2))
    #expect(result.answers == ["frozen": 1, "responsive": 2])
    #expect(result.unanswered == ["frozen"])
}

@Test func aFailedQueryKeepsItsPreviousAnswer() async {
    let result = await TimeboxedQuery.run(["failing"], within: .seconds(5), previous: ["failing": 1]) { _ in nil }

    #expect(result.answers == ["failing": 1])
    #expect(result.unanswered == ["failing"])
}
