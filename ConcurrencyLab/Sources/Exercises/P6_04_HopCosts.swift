import LabKit

// P6.04 — Hop costs: don't ping-pong the main actor
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
        for (index, record) in records.enumerated() {
            blackHole(record &* 31) // the per-record work
            await progress.update(processed: index + 1)
        }
    }
}
