import LabKit

// P3.08 — Build withTimeout
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
        try await operation()
    }
}
