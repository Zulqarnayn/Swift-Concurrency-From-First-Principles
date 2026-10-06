import Foundation

// P0.05 — Deadlock
// Lesson: lessons/P0-foundations/05-deadlock.md
// Test:   swift test --filter P0_05

public final class LockedAccount: @unchecked Sendable {
    public let id: Int
    public let lock = NSLock()
    /// Guarded by `lock`. Only touch it while holding `lock`.
    public var balance: Int

    public init(id: Int, balance: Int) {
        self.id = id
        self.balance = balance
    }
}

public enum P0_05 {
    /// Moves `amount` from one account to the other while holding BOTH locks,
    /// so nobody can observe the money "in flight".
    ///
    /// BUG: thread 1 runs transfer(A → B) while thread 2 runs transfer(B → A).
    /// Thread 1 holds A and waits for B. Thread 2 holds B and waits for A. Forever.
    ///
    /// TODO: make it deadlock-free WITHOUT giving up "hold both locks".
    /// Hint: which of the four deadlock conditions can you break cheaply?
    public static func transfer(from: LockedAccount, to: LockedAccount, amount: Int) {
        from.lock.lock()
        holdBriefly() // keep: simulates work done while holding the first lock
        to.lock.lock()

        from.balance -= amount
        to.balance += amount

        to.lock.unlock()
        from.lock.unlock()
    }
}

/// Simulated work while holding a lock. Don't remove the call.
public func holdBriefly() {
    usleep(20)
}
