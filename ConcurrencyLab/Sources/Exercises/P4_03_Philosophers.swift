import LabKit

// P4.03 — Dining philosophers (can actors deadlock?)
// Lesson: lessons/P4-classics/03-dining-philosophers.md
// Test:   swift test --filter P4_03

/// An async mutex (don't edit). `pickUp` SUSPENDS (doesn't block) until the fork is free; FIFO.
public actor Fork {
    public let id: Int
    private var held = false
    private var waiters: [CheckedContinuation<Void, Never>] = []

    public init(id: Int) { self.id = id }

    public func pickUp() async {
        guard held else {
            held = true
            return
        }
        await withCheckedContinuation { waiters.append($0) } // ownership is handed over on resume
    }

    public func putDown() {
        if waiters.isEmpty { held = false } else { waiters.removeFirst().resume() }
    }
}

/// Don't edit. Counts meals, and records a violation if two neighbours ever eat at the same time.
public final class DiningTable: Sendable {
    public let forks: [Fork]
    private let eating = Locked<Set<Int>>([])
    public let meals = CallCounter()
    public let violations = CallCounter()

    public init(seats: Int) {
        forks = (0..<seats).map(Fork.init(id:))
    }

    public func eat(_ philosopher: Int) async {
        let n = forks.count
        eating.withLock { s in
            if s.contains((philosopher + 1) % n) || s.contains((philosopher + n - 1) % n) { violations.increment() }
            s.insert(philosopher)
        }
        await suspend(ms: 1)
        eating.withLock { _ = $0.remove(philosopher) }
        meals.increment()
    }
}

public enum P4_03 {
    /// Philosopher `i` needs forks `i` and `(i + 1) % n`. Every philosopher eats `meals` times.
    ///
    /// BUG: everyone picks up their LEFT fork, thinks a moment, then reaches for the RIGHT one.
    /// All five hold one fork and wait forever for the other. No thread is blocked — every task is
    /// suspended — so nothing crashes, the CPU is idle, and the feature simply never completes.
    /// TODO: make it impossible to deadlock. (Which Coffman condition can you break? P0.05.)
    public static func dine(at table: DiningTable, meals: Int) async {
        let n = table.forks.count
        await withTaskGroup(of: Void.self) { group in
            for i in 0..<n {
                group.addTask {
                    let left = table.forks[i]
                    let right = table.forks[(i + 1) % n]
                    for _ in 0..<meals {
                        await left.pickUp()
                        await suspend(ms: 1) // thinking while holding one fork
                        await right.pickUp()
                        await table.eat(i)
                        await right.putDown()
                        await left.putDown()
                    }
                }
            }
        }
    }
}
