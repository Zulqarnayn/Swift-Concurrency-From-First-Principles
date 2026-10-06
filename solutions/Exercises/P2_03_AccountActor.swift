import Dispatch
import LabKit

// P2.03 — SOLUTION. Actors vs serial queues
// Lesson: lessons/P2-isolation/03-actors-vs-queues.md
// Test:   swift test --filter P2_03

/// The GCD version (works; don't edit). Every access goes through a private serial queue.
public final class QueueAccount: @unchecked Sendable {
    private let queue = DispatchQueue(label: "QueueAccount")
    private var _balance: Int

    public init(balance: Int) { _balance = balance }

    public var balance: Int { queue.sync { _balance } }
    public func deposit(_ amount: Int) { queue.sync { _balance += amount } }
    public func withdraw(_ amount: Int) -> Bool {
        queue.sync {
            guard _balance >= amount else { return false }
            _balance -= amount
            return true
        }
    }
}

/// SOLUTION: an actor. The compiler now routes every access through the actor's serial executor.
public actor AccountActor {
    private var _balance: Int

    public init(balance: Int) { _balance = balance }

    public var balance: Int { _balance } // read from outside with `await account.balance`

    public func deposit(_ amount: Int) {
        _balance += amount
    }

    public func withdraw(_ amount: Int) -> Bool {
        guard _balance >= amount else { return false }
        _balance -= amount
        return true
    }

    public func transfer(_ amount: Int, to other: AccountActor) async -> Bool {
        // 1. Check + debit on THIS actor with no suspension point in between (sync code = atomic here).
        guard withdraw(amount) else { return false }
        // 2. Hop to the other actor. While we're suspended the money is "in flight": it's in neither
        //    balance. Fine for this API (it will arrive), but an auditor summing both balances at this
        //    instant would see it missing. If that matters, you need a single owner of both balances.
        // 3. Note: no deadlock possible, unlike P0.05's two locks. We never HOLD this actor while
        //    waiting for the other one — the await releases it.
        await other.deposit(amount)
        return true
    }
}
