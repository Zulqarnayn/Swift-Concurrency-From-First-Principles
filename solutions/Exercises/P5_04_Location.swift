import Foundation
import LabKit
@preconcurrency import UnsafeZone

// P5.04 — SOLUTION. Bug hunt: "the location spinner sometimes spins forever"
// Lesson: lessons/P5-bug-zoo/04-continuations.md
// Repro:  swift run lab p5.04        Test: swift test --filter P5_04

public enum LocationError: Error, Equatable {
    case denied
}

/// Bridges the delegate callbacks to ONE continuation, resumed exactly once, whichever path wins:
/// update, failure, or cancellation. `@unchecked Sendable` is honest here: all mutable state is behind a lock.
final class LocationCallbackAdapter: LegacyLocationDelegate, @unchecked Sendable {
    private let provider: LegacyLocationProvider
    private let lock = NSLock()
    private var continuation: CheckedContinuation<Int, any Error>?
    private var cancelled = false

    init(provider: LegacyLocationProvider) {
        self.provider = provider
    }

    func start(_ continuation: CheckedContinuation<Int, any Error>) {
        let alreadyCancelled = lock.withLock {
            self.continuation = continuation
            return cancelled
        }
        if alreadyCancelled { return finish(.failure(CancellationError())) }
        provider.delegate = self
        provider.requestLocation()
    }

    func cancel() {
        lock.withLock { cancelled = true }
        provider.stop()
        finish(.failure(CancellationError()))
    }

    func provider(_ provider: LegacyLocationProvider, didUpdate location: Int) {
        finish(.success(location))
    }

    // ROOT CAUSE #2: this was empty. A denied permission never resumed the continuation → spinner forever.
    func provider(_ provider: LegacyLocationProvider, didFailWith error: any Error) {
        finish(.failure(LocationError.denied))
    }

    /// Take-once: the first caller resumes, every later caller finds nil. No double resume possible.
    private func finish(_ result: Result<Int, any Error>) {
        let taken = lock.withLock { () -> CheckedContinuation<Int, any Error>? in
            defer { continuation = nil }
            return continuation
        }
        taken?.resume(with: result)
    }
}

public enum P5_04 {
    public static func currentLocation(from provider: LegacyLocationProvider) async throws -> Int {
        // ROOT CAUSE #1: the adapter was created INSIDE the continuation closure and only stored in a
        // WEAK delegate property → deallocated when the closure returned → no callback ever arrived.
        // (Written as `provider.delegate = Adapter(...)` the compiler even warns: "instance will be
        // immediately deallocated because property 'delegate' is 'weak'". Read your warnings.)
        // FIX: keep a strong reference for the whole wait — this local lives until the await returns.
        let adapter = LocationCallbackAdapter(provider: provider)
        // ROOT CAUSE #3: cancellation wasn't forwarded, so a cancelled request waited forever.
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { adapter.start($0) }
        } onCancel: {
            adapter.cancel()
        }
    }
}
