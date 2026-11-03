import Foundation
import Synchronization

public struct TimeboxedAnswers<Key: Hashable & Sendable, Value: Sendable>: Sendable {
    public let answers: [Key: Value]
    /// Failed or missed the deadline: their answer, if any, is the latest one that arrived.
    public let unanswered: Set<Key>
}

/// Asks every key at once, each on its own thread, and stops waiting at the deadline, so one slow or frozen
/// app delays neither the others nor the result. A blocking query on a thread of its own keeps the
/// cooperative pool free.
/// A key whose query is still running is not asked again, so a frozen app holds one thread, not one per run.
/// An answer past the deadline is still kept: a slow but alive app shows its windows one run late, never stale.
public final class TimeboxedQuery<Key: Hashable & Sendable, Value: Sendable>: Sendable {
    private struct Run {
        var awaited: Set<Key>
        var fresh: [Key: Value] = [:]
        let waiter: CheckedContinuation<[Key: Value], Never>
    }

    private struct State {
        var latest: [Key: Value] = [:]
        var inFlight: Set<Key> = []
        var runs: [Int: Run] = [:]
        var nextRun = 0
    }

    private let state = Mutex(State())

    public init() {}

    public func run(
        _ keys: [Key],
        within timeout: Duration,
        _ query: @escaping @Sendable (Key) -> Value?
    ) async -> TimeboxedAnswers<Key, Value> {
        var deadline: Task<Void, Never>?
        let fresh = await withCheckedContinuation { waiter in
            let (id, toAsk) = state.withLock { state in
                let id = state.nextRun
                state.nextRun += 1
                state.runs[id] = Run(awaited: Set(keys), waiter: waiter)
                return (id, Set(keys).filter { state.inFlight.insert($0).inserted })
            }
            // Started once the run is registered, so the deadline always finds it.
            deadline = Task { [self] in
                try? await Task.sleep(for: timeout)
                finish(id)
            }
            if keys.isEmpty { finish(id) }
            for key in toAsk {
                Thread { [self] in deliver(query(key), for: key) }.start()
            }
        }
        deadline?.cancel()
        return state.withLock { state in
            state.latest = state.latest.filter { keys.contains($0.key) }
            var answers: [Key: Value] = [:]
            var unanswered: Set<Key> = []
            for key in keys {
                if fresh[key] == nil { unanswered.insert(key) }
                answers[key] = fresh[key] ?? state.latest[key]
            }
            return TimeboxedAnswers(answers: answers, unanswered: unanswered)
        }
    }

    private func deliver(_ answer: Value?, for key: Key) {
        let finished = state.withLock { state in
            state.inFlight.remove(key)
            if let answer { state.latest[key] = answer }
            var finished: [(CheckedContinuation<[Key: Value], Never>, [Key: Value])] = []
            for (id, var run) in state.runs where run.awaited.contains(key) {
                run.awaited.remove(key)
                run.fresh[key] = answer
                if run.awaited.isEmpty {
                    state.runs[id] = nil
                    finished.append((run.waiter, run.fresh))
                } else {
                    state.runs[id] = run
                }
            }
            return finished
        }
        for (waiter, fresh) in finished { waiter.resume(returning: fresh) }
    }

    /// Resumes the run at most once: a run already answered by every key is gone.
    private func finish(_ id: Int) {
        guard let run = state.withLock({ $0.runs.removeValue(forKey: id) }) else { return }
        run.waiter.resume(returning: run.fresh)
    }
}
