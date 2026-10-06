import LabKit

// P4.05 — Rate limiting: a token bucket
// Lesson: lessons/P4-classics/05-rate-limiter.md
// Test:   swift test --filter P4_05

/// At most `capacity` calls in a burst; after that, one new token every `refillInterval`.
/// `acquire()` SUSPENDS until a token is available. Cancelling a waiting caller throws CancellationError.
///
/// BUG: no limiting at all.
/// TODO: track tokens (refill lazily from elapsed time); when empty, sleep until the next token —
/// then CHECK AGAIN (other callers may have woken first: reentrancy). "while", not "if".
public actor TokenBucket {
    public let capacity: Int
    public let refillInterval: Duration

    public init(capacity: Int, refillInterval: Duration) {
        self.capacity = capacity
        self.refillInterval = refillInterval
    }

    public func acquire() async throws {
        // TODO
    }
}
