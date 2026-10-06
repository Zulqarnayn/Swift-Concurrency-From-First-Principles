import LabKit

// P3.09 — SOLUTION. Priority and Task.yield
// Lesson: lessons/P3-structured/09-priority-yield.md
// Test:   swift test --filter P3_09

@MainActor
public enum P3_09 {
    /// Processes items ON THE MAIN ACTOR (it updates UI state as it goes). ~2ms of CPU per item.
    ///
    /// BUG: 50 items = 100ms during which nothing else on the main actor can run (taps, animations,
    /// other tasks). TODO: let other main-actor work interleave, without moving the work off main.
    /// Returns the number of items processed.
    public static func processAll(_ items: [Int]) async -> Int {
        var processed = 0
        for (index, _) in items.enumerated() {
            burnCPU(ms: 2)
            processed += 1
            // Every few items, give other main-actor jobs a turn. Task.yield() suspends and re-enqueues
            // this task, so taps, animations and other tasks queued on main can run in between.
            // (If the work doesn't need main at all, move it off main with @concurrent instead.)
            if index % 2 == 1 { await Task.yield() }
        }
        return processed
    }
}
