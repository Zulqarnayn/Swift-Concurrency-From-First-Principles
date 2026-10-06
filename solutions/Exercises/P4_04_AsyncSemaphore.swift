import Foundation
import LabKit

// P4.04 — SOLUTION. An async semaphore
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
    private var waiters: [(id: UUID, continuation: CheckedContinuation<Void, any Error>)] = []

    public init(value: Int) {
        self.value = value
    }

    public func wait() async throws {
        try Task.checkCancellation()
        if value > 0 {
            value -= 1
            return
        }
        let id = UUID()
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
                // Runs synchronously on the actor. If cancellation already happened, don't park at all.
                if Task.isCancelled {
                    continuation.resume(throwing: CancellationError())
                } else {
                    waiters.append((id, continuation))
                }
            }
        } onCancel: {
            // May run on any thread, at any moment — hop onto the actor to touch `waiters`.
            // Because that hop is queued behind the code above, the waiter is always registered by then.
            Task { await self.cancelWaiter(id) }
        }
    }

    public func signal() {
        if waiters.isEmpty {
            value += 1
        } else {
            // Hand the permit DIRECTLY to the oldest waiter (FIFO). Never increment-then-wake:
            // a newcomer could sneak in between and steal it.
            waiters.removeFirst().continuation.resume()
        }
    }

    private func cancelWaiter(_ id: UUID) {
        // If it's no longer in the list, signal() already gave it a permit — nothing to undo.
        guard let index = waiters.firstIndex(where: { $0.id == id }) else { return }
        waiters.remove(at: index).continuation.resume(throwing: CancellationError())
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
