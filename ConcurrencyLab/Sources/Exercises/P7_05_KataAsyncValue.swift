// P7.05 — Timed kata (25 min): an observable async value
// Lesson: lessons/P7-interview/05-kata-async-value.md
// Test:   swift test --filter P7_05

/// A value that changes over time, observable by any number of async subscribers
/// (an async CurrentValueSubject / a tiny Observation for non-UI code).
///  - `values()` yields the CURRENT value immediately, then every later value
///  - each subscriber is independent; a slow subscriber gets the LATEST value, not a backlog
///    (it's state, not events: intermediate values may be skipped)
///  - a subscriber that stops iterating is removed
///  - `finish()` ends every subscriber's loop; `values()` after finish yields the current value, then ends
public final class AsyncValue<Value: Sendable>: Sendable {
    private let initial: Value

    public init(_ initial: Value) {
        self.initial = initial
    }

    public var value: Value {
        initial
    }

    public func send(_ newValue: Value) {}

    public func values() -> AsyncStream<Value> {
        AsyncStream { $0.finish() }
    }

    public func finish() {}

    public var subscriberCount: Int { 0 }
}
