import SwitcherCore
import Testing

private func wheel(_ deltaY: Double, deltaX: Double = 0) -> ScrollSample {
    ScrollSample(source: .wheel, deltaX: deltaX, deltaY: deltaY)
}

private func gesture(_ phase: ScrollSample.GesturePhase, _ deltaY: Double, deltaX: Double = 0) -> ScrollSample {
    ScrollSample(source: .gesture(phase), deltaX: deltaX, deltaY: deltaY)
}

@Test func eachWheelNotchIsOneStep() {
    var stepper = ScrollStepper()

    let steps = [wheel(-1), wheel(-1), wheel(1)].map { stepper.step(for: $0) }

    #expect(steps == [.down, .down, .up])
}

@Test func horizontalScrollNeverSteps() {
    var stepper = ScrollStepper()

    let samples = [wheel(0, deltaX: 1), wheel(1, deltaX: -3), gesture(.began, 0), gesture(.changed, -7, deltaX: 20)]

    let steps = samples.map { stepper.step(for: $0) }

    #expect(steps == [nil, nil, nil, nil])
}

@Test func aGestureStepsOnceItTravelsTheThresholdThenNeverAgain() {
    var stepper = ScrollStepper()
    let samples = [
        gesture(.began, 0), gesture(.changed, -3), gesture(.changed, -4), gesture(.changed, -20),
        ScrollSample(source: .momentum, deltaX: 0, deltaY: -30), gesture(.ended, 0),
    ]

    let steps = samples.map { stepper.step(for: $0) }

    #expect(steps == [nil, nil, .down, nil, nil, nil])
}

@Test func theNextGestureStepsAgainInItsOwnDirection() {
    var stepper = ScrollStepper()
    for sample in [gesture(.began, 0), gesture(.changed, -10), gesture(.ended, 0)] {
        _ = stepper.step(for: sample)
    }

    let steps = [gesture(.began, 0), gesture(.changed, 10)].map { stepper.step(for: $0) }

    #expect(steps == [nil, .up])
}

@Test func momentumAloneNeverSteps() {
    var stepper = ScrollStepper()

    let step = stepper.step(for: ScrollSample(source: .momentum, deltaX: 0, deltaY: -50))

    #expect(step == nil)
}

@Test func unphasedScrollStepsOncePerBurst() {
    var stepper = ScrollStepper()
    let samples = [0, 0.1, 0.2, 1.0].map { ScrollSample(source: .unphased(at: $0), deltaX: 0, deltaY: -7) }

    let steps = samples.map { stepper.step(for: $0) }

    #expect(steps == [.down, nil, nil, .down])
}
