import LabKit

// P4.08 — Latches and barriers
// Lesson: lessons/P4-classics/08-latch-barrier.md
// Test:   swift test --filter P4_08

/// A one-shot gate: `wait()` suspends until `countDown()` has been called `count` times.
/// After that, every `wait()` (even later ones) returns immediately.
///
/// BUG: never waits. TODO: implement with parked continuations.
public actor CountdownLatch {
    private var count: Int

    public init(count: Int) {
        self.count = count
    }

    public func countDown() {
        count = max(0, count - 1)
    }

    public func wait() async {
        // TODO
    }
}

/// A REUSABLE rendezvous for `parties` tasks: each `arriveAndWait()` suspends until all `parties`
/// have arrived, then all are released together — and the barrier resets for the next round.
///
/// BUG: never waits. TODO: implement it. Careful with the reset: the next round's early arrivals
/// must not be released by the previous round.
public actor CyclicBarrier {
    public let parties: Int

    public init(parties: Int) {
        self.parties = parties
    }

    public func arriveAndWait() async {
        // TODO
    }
}
