import Foundation
import Synchronization

// P0.04 — SOLUTION

public final class BankAccount: Sendable {
    private let balance: Mutex<Int>

    public init(balance: Int) {
        self.balance = Mutex(balance)
    }

    public var current: Int {
        balance.withLock { $0 }
    }

    public func withdraw(_ amount: Int) -> Bool {
        // Check and act inside ONE critical section: no other thread can change
        // the balance between "is there enough?" and "take it".
        balance.withLock { balance in
            guard balance >= amount else { return false }
            simulateLatency()
            balance -= amount
            return true
        }
    }
}

public func simulateLatency() {
    usleep(200)
}
