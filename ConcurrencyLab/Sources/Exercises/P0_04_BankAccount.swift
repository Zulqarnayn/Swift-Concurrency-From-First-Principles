import Foundation
import Synchronization

// P0.04 — Locks and race conditions (check-then-act)
// Lesson: lessons/P0-foundations/04-locks-race-conditions.md
// Test:   swift test --filter P0_04
//
// This file compiles cleanly in Swift 6. There is no data race. There is still a bug.

public final class BankAccount: Sendable {
    private let balance: Mutex<Int>

    public init(balance: Int) {
        self.balance = Mutex(balance)
    }

    public var current: Int {
        balance.withLock { $0 }
    }

    /// Withdraws `amount` only if there is enough money. Returns true on success.
    ///
    /// BUG: the check and the update are two separate critical sections.
    /// TODO: make check + update ONE critical section.
    public func withdraw(_ amount: Int) -> Bool {
        guard current >= amount else { return false }
        simulateLatency() // keep this call: it widens the race window so the bug shows up reliably
        balance.withLock { $0 -= amount }
        return true
    }
}

/// Pretend some work happens here (logging, fraud check...). Don't remove the calls to it.
public func simulateLatency() {
    usleep(200)
}
