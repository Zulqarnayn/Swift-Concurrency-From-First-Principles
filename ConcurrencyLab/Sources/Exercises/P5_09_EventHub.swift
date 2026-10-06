import LabKit

// P5.09 — Bug hunt: "the second screen showing live scores misses half the updates, and never closes cleanly"
// Lesson: lessons/P5-bug-zoo/09-ordering-streams.md
// Repro:  swift run lab p5.09        Test: swift test --filter P5_09

/// Broadcasts live events to every screen that subscribes.
public final class EventHub: Sendable {
    private let pair = AsyncStream.makeStream(of: Int.self)

    public init() {}

    /// Each screen calls this and iterates the result with `for await`.
    public func subscribe() -> AsyncStream<Int> {
        pair.stream
    }

    /// Called (synchronously) by the socket layer for every event, in order.
    public func publish(_ event: Int) {
        pair.continuation.yield(event)
    }

    /// Called on logout. Every subscriber's loop must end.
    public func shutdown() {}

    /// Number of live subscriptions (for diagnostics).
    public var subscriberCount: Int { 1 }
}
