import Foundation
import Synchronization

public struct TimeboxedAnswers<Key: Hashable & Sendable, Value: Sendable>: Sendable {
    public let answers: [Key: Value]
    /// Failed or missed the deadline: their answer, if any, is the previous one.
    public let unanswered: Set<Key>
}

/// Asks every key at once, each on its own thread, and stops waiting at the deadline, so one slow or frozen
/// app delays neither the others nor the result. A blocking query on a thread of its own keeps the
/// cooperative pool free.
public enum TimeboxedQuery {
    public static func run<Key: Hashable & Sendable, Value: Sendable>(
        _ keys: [Key],
        within timeout: Duration,
        previous: [Key: Value],
        _ query: @escaping @Sendable (Key) -> Value?
    ) async -> TimeboxedAnswers<Key, Value> {
        let fresh = await Collector<Key, Value>(pending: keys.count).collect(keys, within: timeout, query)
        var answers: [Key: Value] = [:]
        var unanswered: Set<Key> = []
        for key in keys {
            if let answer = fresh[key] {
                answers[key] = answer
            } else {
                unanswered.insert(key)
                answers[key] = previous[key]
            }
        }
        return TimeboxedAnswers(answers: answers, unanswered: unanswered)
    }
}

private final class Collector<Key: Hashable & Sendable, Value: Sendable>: Sendable {
    private struct State {
        var answers: [Key: Value] = [:]
        var pending: Int
        /// Answered by every key or past the deadline.
        var isOver = false
        var waiter: CheckedContinuation<[Key: Value], Never>?
    }

    private let state: Mutex<State>

    init(pending: Int) {
        state = Mutex(State(pending: pending))
    }

    func collect(
        _ keys: [Key],
        within timeout: Duration,
        _ query: @escaping @Sendable (Key) -> Value?
    ) async -> [Key: Value] {
        let deadline = Task { [self] in
            try? await Task.sleep(for: timeout)
            state.withLock { $0.isOver = true }
            finish()
        }
        defer { deadline.cancel() }
        return await withCheckedContinuation { waiter in
            let isDone = state.withLock { state in
                state.waiter = waiter
                return state.isOver || state.pending == 0
            }
            if isDone { finish() }
            for key in keys {
                Thread { [self] in deliver(query(key), for: key) }.start()
            }
        }
    }

    private func deliver(_ answer: Value?, for key: Key) {
        let isDone = state.withLock { state in
            guard !state.isOver else { return false }
            state.answers[key] = answer
            state.pending -= 1
            state.isOver = state.pending == 0
            return state.isOver
        }
        if isDone { finish() }
    }

    /// Resumes the waiter once: answers arriving after the deadline are dropped.
    private func finish() {
        let resumption = state.withLock { state -> (CheckedContinuation<[Key: Value], Never>, [Key: Value])? in
            guard let waiter = state.waiter else { return nil }
            state.waiter = nil
            return (waiter, state.answers)
        }
        if let (waiter, answers) = resumption { waiter.resume(returning: answers) }
    }
}
