import LabKit

// P1.01 — async/await: suspension, not blocking
// Lesson: lessons/P1-async-await/01-async-await.md
// Test:   swift test --filter P1_01

public enum P1_01 {
    /// Pretend this is a network call that takes 100ms and returns n².
    ///
    /// BUG: it BLOCKS its thread for 100ms. It's marked `async`, but `async` doesn't make code
    /// non-blocking — it only *allows* it to suspend. 32 of these at once on an 8-thread pool
    /// take 4 rounds (≈400ms) instead of ≈100ms.
    ///
    /// TODO: make it wait WITHOUT holding a thread. Use `Task.sleep(for:)`.
    /// The function is `throws` so you can propagate the error `Task.sleep` throws when cancelled.
    public static func slowSquare(_ n: Int) async throws -> Int {
        blockThread(ms: 100)
        return n * n
    }
}
