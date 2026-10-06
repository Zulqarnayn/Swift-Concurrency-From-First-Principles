import LabKit

// P2.05 — SOLUTION. MainActor and global actors
// Lesson: lessons/P2-isolation/05-global-actors.md
// Test:   swift test --filter P2_05

@globalActor
public actor DatabaseActor {
    public static let shared = DatabaseActor()
}

/// The whole type is isolated to DatabaseActor: every method, every property, one at a time.
/// No `@unchecked Sendable` needed — global-actor-isolated classes are Sendable automatically.
@DatabaseActor
public final class Database {
    private var rowCount = 0
    private var lastRow = ""
    private let meter = ConcurrencyMeter()

    /// `nonisolated` so callers anywhere can create one synchronously. Allowed because it only
    /// initializes stored properties; it doesn't call isolated methods.
    nonisolated public init() {}

    public func insert(_ row: String) async {
        meter.enter()
        blockThread(ms: 1) // no `await` inside → the whole write runs uninterrupted on the actor
        rowCount += 1
        lastRow = row
        meter.leave()
    }

    public func count() async -> Int { rowCount }

    public func peakConcurrentWrites() async -> Int { meter.peak }
}
