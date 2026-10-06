// P7.05 — SOLUTION. Timed kata (25 min): an observable async value
// Lesson: lessons/P7-interview/05-kata-async-value.md
// Test:   swift test --filter P7_05

import LabKit

/// A value that changes over time, observable by any number of async subscribers
/// (an async CurrentValueSubject / a tiny Observation for non-UI code).
///  - `values()` yields the CURRENT value immediately, then every later value
///  - each subscriber is independent; a slow subscriber gets the LATEST value, not a backlog
///    (it's state, not events: intermediate values may be skipped)
///  - a subscriber that stops iterating is removed
///  - `finish()` ends every subscriber's loop; `values()` after finish yields the current value, then ends
public final class AsyncValue<Value: Sendable>: Sendable {
    private struct State {
        var value: Value
        var subscribers: [Int: AsyncStream<Value>.Continuation] = [:]
        var nextID = 0
        var finished = false
    }
    private let state: Locked<State>

    public init(_ initial: Value) {
        state = Locked(State(value: initial))
    }

    public var value: Value {
        state.value.value
    }

    public func send(_ newValue: Value) {
        let targets = state.withLock { s -> [AsyncStream<Value>.Continuation] in
            guard !s.finished else { return [] }
            s.value = newValue
            return Array(s.subscribers.values)
        }
        for continuation in targets { continuation.yield(newValue) }
    }

    public func values() -> AsyncStream<Value> {
        // bufferingNewest(1): a slow subscriber holds at most ONE pending value — the latest.
        // That's the "state, not events" semantics (like Observation / CurrentValueSubject+conflation).
        let (stream, continuation) = AsyncStream.makeStream(of: Value.self, bufferingPolicy: .bufferingNewest(1))
        let (current, id) = state.withLock { s -> (Value, Int?) in
            guard !s.finished else { return (s.value, nil) }
            s.nextID += 1
            s.subscribers[s.nextID] = continuation
            return (s.value, s.nextID)
        }
        // Yield the current value under no lock (yield can run onTermination synchronously).
        // Registered BEFORE yielding, so a concurrent send() can't slip between "read current" and "subscribe"
        // and be lost — at worst the subscriber sees the newer value (buffer of 1 keeps the latest).
        continuation.yield(current)
        guard let id else {
            continuation.finish()
            return stream
        }
        continuation.onTermination = { [weak self] _ in
            self?.state.withLock { _ = $0.subscribers.removeValue(forKey: id) }
        }
        return stream
    }

    public func finish() {
        let targets = state.withLock { s -> [AsyncStream<Value>.Continuation] in
            s.finished = true
            defer { s.subscribers.removeAll() }
            return Array(s.subscribers.values)
        }
        for continuation in targets { continuation.finish() }
    }

    public var subscriberCount: Int { state.value.subscribers.count }
}
