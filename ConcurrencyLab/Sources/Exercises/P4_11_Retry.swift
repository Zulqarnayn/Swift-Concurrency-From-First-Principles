import LabKit

// P4.11 — Retry with exponential backoff
// Lesson: lessons/P4-classics/11-retry-backoff.md
// Test:   swift test --filter P4_11

public enum P4_11 {
    /// Run `operation`; on failure wait and try again, up to `maxAttempts` attempts in total.
    /// Delay before retry k (k = 1, 2, …) is `initialDelay × multiplier^(k-1)`.
    ///  - errors for which `shouldRetry` is false are thrown immediately
    ///  - CancellationError is NEVER retried
    ///  - cancelling the caller during a backoff wait stops IMMEDIATELY with CancellationError
    ///  - when attempts run out, throw the LAST error
    ///
    /// BUG: tries once. TODO.
    public static func retry<T: Sendable>(
        maxAttempts: Int,
        initialDelay: Duration,
        multiplier: Double = 2,
        shouldRetry: @Sendable (any Error) -> Bool = { _ in true },
        operation: @Sendable () async throws -> T
    ) async throws -> T {
        try await operation()
    }
}
