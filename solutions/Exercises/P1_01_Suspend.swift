import LabKit

// P1.01 — SOLUTION

public enum P1_01 {
    public static func slowSquare(_ n: Int) async throws -> Int {
        // Suspends the TASK; the thread goes back to the pool and runs other tasks meanwhile.
        // `try` (not `try?`): if the task is cancelled, Task.sleep throws CancellationError
        // immediately and we propagate it — swallowing it would make cancellation silently not work.
        try await Task.sleep(for: .milliseconds(100))
        return n * n
    }
}
