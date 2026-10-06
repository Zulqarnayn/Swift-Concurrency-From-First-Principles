// P7.03 — Timed kata (25 min): parallel fetch with a limit and a deadline
// Lesson: lessons/P7-interview/03-kata-fetch-all.md
// Test:   swift test --filter P7_03

public struct DeadlineExceeded: Error, Equatable {
    public init() {}
}

public enum P7_03 {
    /// Fetch every id concurrently, with at most `maxConcurrent` fetches in flight.
    /// Return exactly ONE entry per id:
    ///  - `.success(value)` if its fetch finished in time
    ///  - `.failure(error)` if its fetch threw
    ///  - `.failure(DeadlineExceeded())` if it hadn't finished (or started) when `deadline` elapsed —
    ///    and any fetch still running at the deadline must be CANCELLED
    /// The function must return promptly at the deadline (assume fetches honor cancellation).
    public static func fetchAll(
        _ ids: [Int],
        maxConcurrent: Int,
        deadline: Duration,
        fetch: @escaping @Sendable (Int) async throws -> String
    ) async -> [Int: Result<String, any Error>] {
        [:]
    }
}
