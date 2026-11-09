import CoreFoundation
public import CoreGraphics
public import SwitcherCore

extension ScreenRect {
    public init(_ rect: CGRect) {
        self.init(
            x: Double(rect.minX), y: Double(rect.minY), width: Double(rect.width), height: Double(rect.height))
    }
}
