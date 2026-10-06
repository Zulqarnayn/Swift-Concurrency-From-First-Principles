// P7.04 — Timed kata (25 min): concurrent processing, in-order delivery
// Lesson: lessons/P7-interview/04-kata-ordered-pipeline.md
// Test:   swift test --filter P7_04

public enum P7_04 {
    /// Transform every input CONCURRENTLY (at most `maxConcurrent` in flight), but call `emit` with the
    /// results in INPUT order — and as early as possible: result k is emitted as soon as results 0…k exist
    /// (don't wait for everything to finish first). Returns after the last emit.
    public static func mapOrdered(
        _ inputs: [Int],
        maxConcurrent: Int,
        transform: @escaping @Sendable (Int) async -> Int,
        emit: @escaping @Sendable (Int) -> Void
    ) async {
    }
}
