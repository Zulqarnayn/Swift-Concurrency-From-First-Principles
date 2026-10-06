import LabKit

// P6.04 — SOLUTION. Hop costs: don't ping-pong the main actor
// Lesson: lessons/P6-internals/04-hop-costs.md
// Test:   swift test --filter P6_04

/// UI progress for an import (don't edit). `history` records every value the UI was given.
@MainActor
public final class ImportProgress {
    public private(set) var processed = 0
    public private(set) var history: [Int] = []

    public init() {}

    public func update(processed: Int) {
        self.processed = processed
        history.append(processed)
    }
}

public enum P6_04 {
    /// Imports records in the background and keeps the progress UI updated.
    /// Requirements:
    ///  - when it returns, `progress.processed == records.count`
    ///  - the UI hears about progress at least every 10% of the records
    ///  - at most 20 main-actor updates in total, however many records there are
    public static func importAll(_ records: [Int], progress: ImportProgress) async {
        await process(records, progress: progress)
    }

    @concurrent
    private static func process(_ records: [Int], progress: ImportProgress) async {
        // Each `await progress.update` is a thread switch to main and back (~7µs measured in P6.03),
        // AND a main-actor job competing with touches and rendering. 5,000 of them = flooding the UI
        // thread with work nobody can even see (the screen refreshes 60–120×/s).
        // Batch: hop once per 10% (and once at the very end).
        let step = max(1, records.count / 10)
        for (index, record) in records.enumerated() {
            blackHole(record &* 31)
            let done = index + 1
            if done % step == 0 || done == records.count {
                await progress.update(processed: done)
            }
        }
    }
}
