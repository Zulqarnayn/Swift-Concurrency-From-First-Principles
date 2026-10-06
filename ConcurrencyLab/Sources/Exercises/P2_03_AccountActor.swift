import Dispatch
import LabKit

// P2.03 — Actors vs serial queues
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

/// TODO: the same account as an ACTOR — no queue, no @unchecked, no locks.
/// Right now it's a class with no protection at all, so concurrent calls race.
///
/// Then implement `transfer`: move `amount` to `other` only if this account has enough.
/// Think: which part must happen without a suspension point in between? Where can money be "in flight"?
public final class AccountActor: @unchecked Sendable {
    private var _balance: Int

    public init(balance: Int) { _balance = balance }

    public var balance: Int { get async { _balance } }

    public func deposit(_ amount: Int) async {
        _balance += amount
    }

    public func withdraw(_ amount: Int) async -> Bool {
        guard _balance >= amount else { return false }
        _balance -= amount
        return true
    }

    public func transfer(_ amount: Int, to other: AccountActor) async -> Bool {
        // TODO
        false
    }
}
