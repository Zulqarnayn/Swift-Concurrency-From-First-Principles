import LabKit

// P4.05 — SOLUTION. Rate limiting: a token bucket
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
    private var tokens: Double
    private var lastRefill = ContinuousClock.now

    public init(capacity: Int, refillInterval: Duration) {
        self.capacity = capacity
        self.refillInterval = refillInterval
        tokens = Double(capacity)
    }

    public func acquire() async throws {
        while true { // WHILE, not if: after sleeping, others may have taken the token first (reentrancy)
            refill()
            if tokens >= 1 {
                tokens -= 1
                return
            }
            // Sleep until the next token is due. Task.sleep throws on cancellation → we stop waiting.
            let missing = 1 - tokens
            try await Task.sleep(for: refillInterval * missing)
        }
    }

    /// Lazy refill: no timer task. Compute how many tokens accrued since the last check.
    private func refill() {
        let now = ContinuousClock.now
        let accrued = (now - lastRefill) / refillInterval
        tokens = min(Double(capacity), tokens + accrued)
        lastRefill = now
    }
}
