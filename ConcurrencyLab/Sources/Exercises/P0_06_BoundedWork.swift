import Dispatch

// P0.06 — Starvation, priority inversion, thread explosion
// Lesson: lessons/P0-foundations/06-starvation-inversion-explosion.md
// Test:   swift test --filter P0_06

public enum P0_06 {
    /// Runs every job on a concurrent queue, but never more than `limit` jobs at the same time.
    /// Returns when ALL jobs have finished.
    ///
    /// BUG: no limit at all. With blocking jobs, GCD will happily create a thread for each one.
    ///
    /// TODO: limit concurrency with `DispatchSemaphore(value: limit)`.
    /// Think: who calls `wait()` and who calls `signal()`? Where must `signal()` go so it ALWAYS runs?
    ///
    /// (This is the classic GCD answer. In Swift concurrency, blocking like this is forbidden —
    ///  P1.03 explains why, and in P4 you'll build an async semaphore that suspends instead.)
    public static func runAll(_ jobs: [@Sendable () -> Void], limit: Int) {
        let queue = DispatchQueue(label: "work", attributes: .concurrent)
        let group = DispatchGroup()
        for job in jobs {
            queue.async(group: group) {
                job()
            }
        }
        group.wait()
    }
}
