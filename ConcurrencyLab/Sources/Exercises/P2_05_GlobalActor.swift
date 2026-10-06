import LabKit

// P2.05 — MainActor and global actors
// Lesson: lessons/P2-isolation/05-global-actors.md
// Test:   swift test --filter P2_05

// TODO 1: declare a global actor named `DatabaseActor`.

/// Many independent parts of the app write to the database. Writes must never overlap.
///
/// BUG: nothing serializes `insert`. It's a plain async method on a non-isolated class, so concurrent
/// callers run it at the same time (`@unchecked Sendable` hides the problem from the compiler).
///
/// TODO 2: isolate the WHOLE class to `DatabaseActor` (not individual methods: avoid split isolation),
/// and delete `@unchecked Sendable` — you won't need it. Keep `init` callable from anywhere.
public final class Database: @unchecked Sendable {
    private var rowCount = 0
    private var lastRow = ""
    private let meter = ConcurrencyMeter()

    public init() {}

    public func insert(_ row: String) async {
        meter.enter()
        blockThread(ms: 1) // simulated disk write (synchronous)
        rowCount += 1
        lastRow = row
        meter.leave()
    }

    public func count() async -> Int { rowCount }

    /// The most writes that were ever running at the same moment. Must be 1.
    public func peakConcurrentWrites() async -> Int { meter.peak }
}
