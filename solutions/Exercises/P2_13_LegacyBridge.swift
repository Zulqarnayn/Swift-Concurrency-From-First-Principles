import LabKit
@preconcurrency import UnsafeZone

// P2.13 — SOLUTION. @preconcurrency and bridging legacy (Swift 5) code
// Lesson: lessons/P2-isolation/13-preconcurrency-migration.md
// Test:   swift test --filter P2_13

/// `LegacyThermometerClient` lives in a Swift 5 module (Sources/UnsafeZone). It calls `onReading`
/// on a BACKGROUND queue, once per reading.
@MainActor
public final class TemperatureModel {
    public private(set) var readings: [Int] = []
    private let client = LegacyThermometerClient()

    public init() {}

    /// Start the client and record every reading, IN ORDER, on the main actor.
    ///
    /// The "obvious" code is below, commented out. It compiles. Run `swift run lab p2.13b` to see why
    /// it's wrong. TODO: bridge the background callback to the main actor properly.
    public func start(count: Int) {
        let (stream, continuation) = AsyncStream.makeStream(of: Int.self)

        // EXPLICITLY @Sendable: it will run on a background queue, so it must not be inferred @MainActor.
        // All it touches is the continuation, which is Sendable and thread-safe.
        client.onReading = { @Sendable value in
            continuation.yield(value)
        }

        // One consumer on the main actor (inherited by Task {}), so values arrive IN ORDER (P1.08).
        // [weak self]: the model owns the client, which owns the closure, which owns the continuation.
        // When the model goes away, that chain is released, the stream ends, and this loop finishes.
        Task { [weak self] in
            for await value in stream {
                self?.readings.append(value)
            }
        }
        client.start(count: count)
    }
}
