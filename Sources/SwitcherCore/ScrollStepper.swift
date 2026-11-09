/// One scroll event, stripped of AppKit.
public struct ScrollSample: Equatable, Sendable {
    public enum Source: Equatable, Sendable {
        /// A mouse wheel without precise deltas: each event is a notch.
        case wheel
        /// A trackpad or Magic Mouse gesture, fingers on the surface.
        case gesture(GesturePhase)
        /// The momentum that follows a gesture once the fingers lift.
        case momentum
        /// Precise deltas without phases, as some smooth-scrolling mice send; the time is in seconds.
        case unphased(at: Double)
    }

    public enum GesturePhase: Equatable, Sendable {
        case began
        case changed
        case ended
    }

    public let source: Source
    /// Positive to the left and up, as delivered by the system.
    public let deltaX: Double
    public let deltaY: Double

    public init(source: Source, deltaX: Double, deltaY: Double) {
        self.source = source
        self.deltaX = deltaX
        self.deltaY = deltaY
    }
}

/// Turns scroll events into steps: one wheel notch or one gesture, momentum included, is one step, so a swipe
/// never races through the Window list. Horizontal scrolling never steps.
public struct ScrollStepper: Sendable {
    /// Points a gesture travels before it steps. To tune by hand: too low skips windows, too high feels unresponsive.
    public static let gestureThreshold = 6.0
    /// Unphased events further apart than this start a new step.
    public static let unphasedGap = 0.25

    private var travelled = 0.0
    private var hasStepped = false
    private var lastUnphased: Double?

    public init() {}

    public mutating func step(for sample: ScrollSample) -> ScrollDirection? {
        switch sample.source {
        case .wheel:
            return Self.isVertical(sample) ? Self.direction(of: sample.deltaY) : nil
        case .momentum:
            return nil
        case .gesture(.began):
            restart()
            return travel(sample)
        case .gesture(.changed):
            return travel(sample)
        case .gesture(.ended):
            restart()
            return nil
        case .unphased(let time):
            let isSameBurst = lastUnphased.map { time - $0 <= Self.unphasedGap } ?? false
            if !isSameBurst { restart() }
            lastUnphased = time
            return travel(sample)
        }
    }

    private mutating func restart() {
        travelled = 0
        hasStepped = false
    }

    private mutating func travel(_ sample: ScrollSample) -> ScrollDirection? {
        guard !hasStepped, Self.isVertical(sample) else { return nil }
        travelled += sample.deltaY
        guard abs(travelled) >= Self.gestureThreshold else { return nil }
        hasStepped = true
        return Self.direction(of: travelled)
    }

    private static func isVertical(_ sample: ScrollSample) -> Bool {
        sample.deltaY != 0 && abs(sample.deltaY) > abs(sample.deltaX)
    }

    private static func direction(of deltaY: Double) -> ScrollDirection {
        deltaY < 0 ? .down : .up
    }
}
