import LabKit

// P5.09 — SOLUTION. Bug hunt: "the second screen showing live scores misses half the updates, and never closes cleanly"
// Lesson: lessons/P5-bug-zoo/09-ordering-streams.md
// Repro:  swift run lab p5.09        Test: swift test --filter P5_09

/// Broadcasts live events to every screen that subscribes.
public final class EventHub: Sendable {
    private struct State {
        var subscribers: [Int: AsyncStream<Int>.Continuation] = [:]
        var nextID = 0
        var closed = false
    }
    private let state = Locked(State())

    public init() {}

    // ROOT CAUSE #1: one AsyncStream was handed to every screen. AsyncStream is UNICAST (P1.06): each
    // element goes to ONE consumer, so two screens split the events between them.
    // FIX: a separate stream per subscriber; publish yields into all of them.
    public func subscribe() -> AsyncStream<Int> {
        let (stream, continuation) = AsyncStream.makeStream(of: Int.self)
        let id: Int? = state.withLock { s in
            guard !s.closed else { return nil }
            s.nextID += 1
            s.subscribers[s.nextID] = continuation
            return s.nextID
        }
        guard let id else {
            continuation.finish() // already shut down: end immediately
            return stream
        }
        // ROOT CAUSE #3: subscribers that stopped listening were never removed (a slow leak, and wasted
        // yields). onTermination fires when the consumer cancels/breaks and drops the stream (P1.06).
        continuation.onTermination = { [weak self] _ in
            self?.state.withLock { _ = $0.subscribers.removeValue(forKey: id) }
        }
        return stream
    }

    public func publish(_ event: Int) {
        // Synchronous yields from one caller preserve order per subscriber.
        let targets = state.withLock { Array($0.subscribers.values) }
        for continuation in targets { continuation.yield(event) }
    }

    // ROOT CAUSE #2: shutdown() did nothing → every subscriber's `for await` waited forever
    // (tasks and screens leaked, "never closes cleanly"). FIX: finish every stream.
    public func shutdown() {
        let targets = state.withLock { s -> [AsyncStream<Int>.Continuation] in
            s.closed = true
            defer { s.subscribers.removeAll() }
            return Array(s.subscribers.values)
        }
        for continuation in targets { continuation.finish() }
    }

    public var subscriberCount: Int { state.value.subscribers.count }
}
