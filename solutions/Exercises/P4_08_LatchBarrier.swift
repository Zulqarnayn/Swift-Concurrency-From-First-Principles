import LabKit

// P4.08 — SOLUTION. Latches and barriers
// Lesson: lessons/P4-classics/08-latch-barrier.md
// Test:   swift test --filter P4_08

/// A one-shot gate: `wait()` suspends until `countDown()` has been called `count` times.
/// After that, every `wait()` (even later ones) returns immediately.
///
/// BUG: never waits. TODO: implement with parked continuations.
public actor CountdownLatch {
    private var count: Int
    private var waiters: [CheckedContinuation<Void, Never>] = []

    public init(count: Int) {
        self.count = count
    }

    public func countDown() {
        guard count > 0 else { return }
        count -= 1
        if count == 0 {
            for waiter in waiters { waiter.resume() }
            waiters.removeAll()
        }
    }

    public func wait() async {
        guard count > 0 else { return } // already open
        await withCheckedContinuation { waiters.append($0) }
    }
}

/// A REUSABLE rendezvous for `parties` tasks: each `arriveAndWait()` suspends until all `parties`
/// have arrived, then all are released together — and the barrier resets for the next round.
///
/// BUG: never waits. TODO: implement it. Careful with the reset: the next round's early arrivals
/// must not be released by the previous round.
public actor CyclicBarrier {
    public let parties: Int
    private var waiting: [CheckedContinuation<Void, Never>] = []

    public init(parties: Int) {
        self.parties = parties
    }

    public func arriveAndWait() async {
        if waiting.count + 1 == parties {
            // Last to arrive: release this round and reset IN THE SAME synchronous step.
            // Because the list is swapped out before anyone resumes, early arrivals for the next round
            // start a fresh list and can't be released by this round.
            let round = waiting
            waiting = []
            for party in round { party.resume() }
            return
        }
        await withCheckedContinuation { waiting.append($0) }
    }
}
