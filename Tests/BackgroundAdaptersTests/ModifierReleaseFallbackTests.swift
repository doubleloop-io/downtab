import BackgroundAdapters
import Synchronization
import Testing

/// Answers the Modifier state from a script, one answer per check, then reports it up.
private final class ScriptedModifier: Sendable {
    private let remaining: Mutex<[Bool]>
    let checks = Mutex(0)

    init(downChecks: Int) {
        remaining = Mutex(Array(repeating: true, count: downChecks))
    }

    func isDown() -> Bool {
        checks.withLock { $0 += 1 }
        return remaining.withLock { $0.isEmpty ? false : $0.removeFirst() }
    }
}

@Test func returnsAtTheFirstCheckThatSeesTheModifierUp() async throws {
    let modifier = ScriptedModifier(downChecks: 2)
    let sleeps = Mutex(0)
    let fallback = ModifierReleaseFallback(
        isModifierDown: modifier.isDown,
        sleep: { _ in sleeps.withLock { $0 += 1 } }
    )

    try await fallback.waitForRelease()

    #expect(modifier.checks.withLock { $0 } == 3)
    #expect(sleeps.withLock { $0 } == 3)
}

@Test func cancellingWhileTheModifierIsHeldEndsTheWaitWithCancellation() async {
    let fallback = ModifierReleaseFallback(isModifierDown: { true }, sleep: { try await Task.sleep(for: $0) })

    let wait = Task { try await fallback.waitForRelease() }
    wait.cancel()

    await #expect(throws: CancellationError.self) { try await wait.value }
}
