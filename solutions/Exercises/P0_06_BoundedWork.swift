import Dispatch

// P0.06 — SOLUTION

public enum P0_06 {
    public static func runAll(_ jobs: [@Sendable () -> Void], limit: Int) {
        let queue = DispatchQueue(label: "work", attributes: .concurrent)
        let group = DispatchGroup()
        let slots = DispatchSemaphore(value: limit)

        for job in jobs {
            // Wait for a free slot BEFORE submitting. The submitting thread blocks, not a worker,
            // so GCD never has more than `limit` jobs to run → never spawns more than `limit` threads.
            // (Waiting inside the block would also cap concurrency, but GCD would still create a
            //  thread per blocked block — exactly the thread explosion we're trying to avoid.)
            slots.wait()
            queue.async(group: group) {
                defer { slots.signal() } // `defer`: the slot is returned even if the job exits early
                job()
            }
        }
        group.wait()
    }
}
