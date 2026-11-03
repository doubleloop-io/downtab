/// Polls the Modifier state while the Switcher is open, so a release the tap missed (tap disabled,
/// event dropped) still confirms instead of leaving the Switcher stuck open.
public struct ModifierReleaseFallback: Sendable {
    /// Short enough that a missed release still feels like a release, not a hang.
    public static let checkInterval = Duration.milliseconds(50)

    private let isModifierDown: @Sendable () -> Bool
    private let sleep: @Sendable (Duration) async throws -> Void

    public init(
        isModifierDown: @escaping @Sendable () -> Bool = { ModifierReleaseTap.isModifierDown },
        sleep: @escaping @Sendable (Duration) async throws -> Void = { try await Task.sleep(for: $0) }
    ) {
        self.isModifierDown = isModifierDown
        self.sleep = sleep
    }

    /// Returns once a check sees the Modifier up; throws `CancellationError` when cancelled first.
    public func waitForRelease() async throws {
        repeat {
            try await sleep(Self.checkInterval)
            try Task.checkCancellation()
        } while isModifierDown()
    }
}
