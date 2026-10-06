import Foundation

// P0.05 — SOLUTION

public final class LockedAccount: @unchecked Sendable {
    public let id: Int
    public let lock = NSLock()
    public var balance: Int

    public init(id: Int, balance: Int) {
        self.id = id
        self.balance = balance
    }
}

public enum P0_05 {
    public static func transfer(from: LockedAccount, to: LockedAccount, amount: Int) {
        // Break "circular wait": every thread takes locks in the same GLOBAL order (lowest id first).
        // A→B and B→A both lock account 1 first, so they can never each hold what the other wants.
        let (first, second) = from.id < to.id ? (from, to) : (to, from)

        first.lock.lock()
        holdBriefly()
        second.lock.lock()

        from.balance -= amount
        to.balance += amount

        second.lock.unlock()
        first.lock.unlock()
    }
}

public func holdBriefly() {
    usleep(20)
}
