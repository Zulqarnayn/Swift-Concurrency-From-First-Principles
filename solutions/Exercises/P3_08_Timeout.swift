import LabKit

// P3.08 — SOLUTION. Build withTimeout
// Lesson: lessons/P3-structured/08-timeouts.md
// Test:   swift test --filter P3_08

public struct TimeoutError: Error, Equatable {
    public init() {}
}

public enum P3_08 {
    /// Run `operation`. If it hasn't finished within `limit`, cancel it and throw `TimeoutError`.
    ///  - the operation's own errors propagate unchanged
    ///  - if the CALLER is cancelled, throw CancellationError (not TimeoutError)
    ///
    /// BUG: no timeout at all.
    /// TODO: race the operation against a sleeping child task in a ThrowingTaskGroup.
    public static func withTimeout<T: Sendable>(
        _ limit: Duration,
        operation: @escaping @Sendable () async throws -> T
    ) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask { try await operation() }
            group.addTask {
                try await Task.sleep(for: limit) // throws CancellationError if WE are cancelled first
                throw TimeoutError()
            }
            // Whichever child finishes first (value or error) decides the outcome...
            defer { group.cancelAll() } // ...and the loser is cancelled.
            return try await group.next()!
            // Caller cancelled → the group's children are cancelled → the operation (or the sleep)
            // throws CancellationError, which is what next() rethrows. Not TimeoutError. ✓
            //
            // Limit: when the body returns, the group still AWAITS the cancelled loser. If the operation
            // ignores cancellation, the "timeout" ends only when it does (demo p3.08: 603ms for a 100ms
            // limit). That's the price of structure. LabKit.withLabTimeout makes the opposite trade.
        }
    }
}
