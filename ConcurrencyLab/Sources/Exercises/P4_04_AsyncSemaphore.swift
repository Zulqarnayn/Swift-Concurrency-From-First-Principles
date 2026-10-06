import Foundation
import LabKit

// P4.04 — An async semaphore
// Lesson: lessons/P4-classics/04-async-semaphore.md
// Test:   swift test --filter P4_04

/// A counting semaphore for async code: `wait()` SUSPENDS (never blocks a thread) while no permits are left.
/// Requirements:
///  - waiters are woken in FIFO order
///  - a waiter whose task is CANCELLED stops waiting, throws CancellationError, and does NOT take a permit
///  - no polling
///
/// BUG: polls with Task.yield (burns CPU, wakes in random order, ignores cancellation).
/// TODO: park waiters as continuations; `signal()` hands a permit directly to the oldest waiter.
public actor AsyncSemaphore {
    private var value: Int

    public init(value: Int) {
        self.value = value
    }

    public func wait() async throws {
        while value <= 0 {
            await Task.yield()
        }
        value -= 1
    }

    public func signal() {
        value += 1
    }
}

extension AsyncSemaphore {
    /// Run `operation` holding a permit; the permit is always returned. (Don't edit.)
    public nonisolated func withPermit<T: Sendable>(_ operation: @Sendable () async throws -> T) async throws -> T {
        try await wait()
        do {
            let result = try await operation()
            await signal()
            return result
        } catch {
            await signal()
            throw error
        }
    }
}
