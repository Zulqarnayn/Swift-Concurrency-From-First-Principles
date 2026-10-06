import Synchronization

// P0.03 — Atomicity
// Lesson: lessons/P0-foundations/03-atomicity.md
// Test:   swift test --filter P0_03

/// A counter that must never go above `limit`, built ONLY from an `Atomic` (no locks allowed).
public final class BoundedCounter: Sendable {
    public let limit: Int
    private let value = Atomic<Int>(0)

    public init(limit: Int) {
        self.limit = limit
    }

    /// Increments if the value is below `limit`. Returns true if it incremented.
    ///
    /// BUG: `load` is atomic. `store` is atomic. But "load, check, store" is NOT one atomic step.
    /// Two threads can both load 999, both pass the check, both store 1000 — and both return true.
    ///
    /// TODO: rewrite with a compare-and-exchange loop:
    ///   read the current value → if at limit return false →
    ///   try to swap current → current+1 → if another thread changed it first, retry.
    public func tryIncrement() -> Bool {
        let current = value.load(ordering: .relaxed)
        guard current < limit else { return false }
        value.store(current + 1, ordering: .relaxed)
        return true
    }

    public var current: Int {
        value.load(ordering: .relaxed)
    }
}
