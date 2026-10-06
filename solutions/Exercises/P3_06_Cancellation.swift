import Dispatch
import Foundation
import LabKit

// P3.06 — SOLUTION. Cancellation from first principles
// Lesson: lessons/P3-structured/06-cancellation.md
// Test:   swift test --filter P3_06

/// A legacy download with its own cancel button (don't edit).
/// `start` calls back after 500ms with data, or — if `cancel()` is called — right away with `URLError(.cancelled)`.
/// Calling `cancel()` BEFORE `start` makes `start` call back immediately with the cancellation error.
public final class LegacyDownload: Sendable {
    private struct State {
        var completion: (@Sendable (Result<Data, any Error>) -> Void)?
        var cancelled = false
        var finished = false
    }
    private let state = Locked(State())
    public init() {}

    public var wasCancelled: Bool { state.value.cancelled }

    public func start(completion: @escaping @Sendable (Result<Data, any Error>) -> Void) {
        let alreadyCancelled = state.withLock { s -> Bool in
            s.completion = completion
            return s.cancelled
        }
        if alreadyCancelled { return finish(.failure(URLError(.cancelled))) }
        DispatchQueue.global().asyncAfter(deadline: .now() + .milliseconds(500)) { [self] in
            finish(.success(Data("payload".utf8)))
        }
    }

    public func cancel() {
        state.withLock { $0.cancelled = true }
        finish(.failure(URLError(.cancelled)))
    }

    private func finish(_ result: Result<Data, any Error>) {
        let completion = state.withLock { s -> (@Sendable (Result<Data, any Error>) -> Void)? in
            guard !s.finished, let c = s.completion else { return nil }
            s.finished = true
            return c
        }
        completion?(result)
    }
}

public enum P3_06 {
    /// Count primes below `n`. CPU-bound.
    /// BUG: ignores cancellation — a cancelled caller still burns the CPU to the end.
    /// TODO: check for cancellation regularly (not on every iteration: that's wasteful) and throw.
    public static func countPrimes(below n: Int) async throws -> Int {
        var count = 0
        for k in 2..<n {
            // Cancellation is just a flag. Nobody stops this loop but the loop itself.
            // Check often enough to be responsive, rarely enough to be cheap.
            if k % 256 == 0 { try Task.checkCancellation() }
            if (2..<k).allSatisfy({ k % $0 != 0 }) { count += 1 }
        }
        return count
    }

    /// Wrap the legacy download. If the calling task is cancelled, cancel the legacy download
    /// and throw `CancellationError` promptly.
    /// BUG: the continuation works, but cancellation is never forwarded — a cancelled caller waits 500ms.
    /// TODO: forward cancellation (and handle "cancelled before it even started").
    public static func download(_ legacy: LegacyDownload) async throws -> Data {
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                legacy.start { result in
                    // Translate the legacy "cancelled" error into Swift's CancellationError.
                    if case .failure(let error as URLError) = result, error.code == .cancelled {
                        continuation.resume(throwing: CancellationError())
                    } else {
                        continuation.resume(with: result)
                    }
                }
            }
        } onCancel: {
            // Runs IMMEDIATELY when the task is cancelled, concurrently with the operation —
            // possibly BEFORE `legacy.start` was even called (if the task was already cancelled).
            // That race is why LegacyDownload must handle cancel-before-start. Keep this closure tiny
            // and thread-safe: it's @Sendable and may run on any thread.
            legacy.cancel()
        }
    }
}
