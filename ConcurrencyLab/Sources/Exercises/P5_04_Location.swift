import LabKit
@preconcurrency import UnsafeZone

// P5.04 — Bug hunt: "the location spinner sometimes spins forever"
// Lesson: lessons/P5-bug-zoo/04-continuations.md
// Repro:  swift run lab p5.04        Test: swift test --filter P5_04

public enum LocationError: Error, Equatable {
    case denied
}

/// Bridges the delegate callback to the continuation.
final class LocationCallbackAdapter: LegacyLocationDelegate {
    private let continuation: CheckedContinuation<Int, any Error>

    init(continuation: CheckedContinuation<Int, any Error>) {
        self.continuation = continuation
    }

    func provider(_ provider: LegacyLocationProvider, didUpdate location: Int) {
        continuation.resume(returning: location)
    }

    func provider(_ provider: LegacyLocationProvider, didFailWith error: any Error) {}
}

public enum P5_04 {
    /// One-shot location. Throws `LocationError.denied` if permission is denied.
    /// Cancelling the calling task must stop the provider and throw CancellationError.
    public static func currentLocation(from provider: LegacyLocationProvider) async throws -> Int {
        try await withCheckedThrowingContinuation { continuation in
            let adapter = LocationCallbackAdapter(continuation: continuation)
            provider.delegate = adapter
            provider.requestLocation()
        }
    }
}
