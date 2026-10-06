import Dispatch
import Foundation
import LabKit

// P3.06 — Cancellation from first principles
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
        for k in 2..<n where (2..<k).allSatisfy({ k % $0 != 0 }) {
            count += 1
        }
        return count
    }

    /// Wrap the legacy download. If the calling task is cancelled, cancel the legacy download
    /// and throw `CancellationError` promptly.
    /// BUG: the continuation works, but cancellation is never forwarded — a cancelled caller waits 500ms.
    /// TODO: forward cancellation (and handle "cancelled before it even started").
    public static func download(_ legacy: LegacyDownload) async throws -> Data {
        try await withCheckedThrowingContinuation { continuation in
            legacy.start { continuation.resume(with: $0) }
        }
    }
}
