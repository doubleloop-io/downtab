/// AppKit's coordinates unless stated otherwise: origin at the menu bar display's bottom-left corner, y up.
public struct ScreenPoint: Equatable, Sendable {
    public let x: Double
    public let y: Double

    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }
}

public struct ScreenRect: Equatable, Sendable {
    public let x: Double
    public let y: Double
    public let width: Double
    public let height: Double

    public init(x: Double, y: Double, width: Double, height: Double) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }

    var maxX: Double { x + width }
    var maxY: Double { y + height }

    /// As AppKit's `NSMouseInRect` for unflipped coordinates: the pointer on a display's top row is at its top edge.
    func containsPointer(_ point: ScreenPoint) -> Bool {
        point.x >= x && point.x < maxX && point.y > y && point.y <= maxY
    }

    func overlapArea(with other: ScreenRect) -> Double {
        let overlapWidth = max(0, min(maxX, other.maxX) - max(x, other.x))
        let overlapHeight = max(0, min(maxY, other.maxY) - max(y, other.y))
        return overlapWidth * overlapHeight
    }
}
