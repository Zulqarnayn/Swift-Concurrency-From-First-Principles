import LabKit

// P2.10 — Isolation inheritance and isolated parameters
// Lesson: lessons/P2-isolation/10-isolation-inheritance.md
// Test:   swift test --filter P2_10

/// Don't edit.
public actor Inventory {
    private var stock: [String: Int]
    public private(set) var lowestStock = Int.max

    public init(stock: [String: Int]) {
        self.stock = stock
    }

    public func available(_ item: String) -> Int {
        stock[item, default: 0]
    }

    /// Takes one unit. Does NOT check availability (callers must).
    public func take(_ item: String) {
        stock[item, default: 0] -= 1
        lowestStock = min(lowestStock, stock[item, default: 0])
    }
}

public enum P2_10 {
    /// Reserve one of EACH item, all-or-nothing. Returns true if everything was reserved.
    ///
    /// BUG: every `await inventory.…` is a separate trip to the actor. Between trips, other callers'
    /// calls run — so two callers can both see "1 left" and both take it. Stock goes negative.
    ///
    /// TODO: make the whole check-and-take run as ONE uninterrupted piece of work on the actor.
    /// Constraint: don't edit `Inventory`. (Hint: a function can borrow an actor's isolation.)
    /// The call site `await P2_10.reserveAll(items, in: inventory)` must keep compiling.
    public static func reserveAll(_ items: [String], in inventory: Inventory) async -> Bool {
        for item in items {
            guard await inventory.available(item) > 0 else { return false }
        }
        await Task.yield() // e.g. logging, analytics... any suspension point
        for item in items {
            await inventory.take(item)
        }
        return true
    }
}
