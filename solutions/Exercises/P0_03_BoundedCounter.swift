import Synchronization

// P0.03 — SOLUTION

public final class BoundedCounter: Sendable {
    public let limit: Int
    private let value = Atomic<Int>(0)

    public init(limit: Int) {
        self.limit = limit
    }

    public func tryIncrement() -> Bool {
        var current = value.load(ordering: .relaxed)
        while current < limit {
            // "If value is STILL `current`, make it current+1." One indivisible hardware step.
            let (exchanged, original) = value.compareExchange(
                expected: current,
                desired: current + 1,
                ordering: .relaxed
            )
            if exchanged { return true }
            // Someone else changed it between our load and our CAS. Retry with what they wrote.
            current = original
        }
        return false
    }

    public var current: Int {
        value.load(ordering: .relaxed)
    }
}
