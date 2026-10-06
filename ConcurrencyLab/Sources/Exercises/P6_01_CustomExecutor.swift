import Dispatch
import LabKit

// P6.01 — Executors: running an actor on a queue you choose
// Lesson: lessons/P6-internals/01-executors.md
// Test:   swift test --filter P6_01

/// A legacy C database binding (don't edit). Its rule, like many C libraries (SQLite in some modes,
/// Core Data's old confinement, some audio/graphics APIs): EVERY call must happen on its queue.
/// Calls from anywhere else are recorded as violations.
public final class LegacyDatabase: @unchecked Sendable {
    public let queue = DispatchSerialQueue(label: "legacy.db.queue")
    public let violations = CallCounter()
    private var rows: [String] = []

    public init() {}

    public func exec(_ statement: String) -> String {
        if currentQueueLabel() != "legacy.db.queue" { violations.increment() }
        rows.append(statement)
        return currentQueueLabel()
    }
}

/// An actor wrapping the legacy database.
/// TODO: make EVERY method of this actor run on `legacy.queue` — without wrapping each method body
/// in `queue.sync` (that would block callers and bypass the actor). One declaration does it.
public actor QueueBoundDatabase {
    public nonisolated let legacy = LegacyDatabase()

    public init() {}

    public func insert(_ row: String) -> String {
        legacy.exec("INSERT \(row)")
    }

    public func count() -> String {
        legacy.exec("SELECT COUNT(*)")
    }
}
