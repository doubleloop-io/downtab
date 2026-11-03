/// Turns periodic readings of the Accessibility permission into the moments it is granted or revoked.
/// macOS sends no notification for either, so Downtab polls and reacts only to changes.
public struct PermissionWatch: Sendable {
    public enum Change: Equatable, Sendable {
        case granted
        case revoked
    }

    private var isGranted: Bool?

    public init() {}

    /// The first reading is a change: at launch Downtab has not yet acted on either state.
    public mutating func observe(isGranted granted: Bool) -> Change? {
        guard granted != isGranted else { return nil }
        isGranted = granted
        return granted ? .granted : .revoked
    }
}
