import Dispatch
import LabKit

// P1.06 — SOLUTION. AsyncSequence and AsyncStream
// Lesson: lessons/P1-async-await/06-async-sequences.md
// Test:   swift test --filter P1_06

/// Legacy push-based API (don't edit). After `start`, calls `handler` every ~5ms with
/// 60, 61, 62, ... on a background queue, until `stop()`.
public final class LegacyHeartRateMonitor: Sendable {
    private struct State {
        var running = false
        var next = 60
        var generation = 0
    }
    private let state = Locked(State())
    private let queue = DispatchQueue(label: "heart-rate")

    public init() {}

    public func start(handler: @escaping @Sendable (Int) -> Void) {
        let generation = state.withLock { s -> Int in
            s.running = true
            s.generation += 1
            return s.generation
        }
        tick(generation, handler)
    }

    public func stop() {
        state.withLock { $0.running = false }
    }

    public var isRunning: Bool { state.value.running }

    private func tick(_ generation: Int, _ handler: @escaping @Sendable (Int) -> Void) {
        queue.asyncAfter(deadline: .now() + .milliseconds(5)) { [self] in
            let value = state.withLock { s -> Int? in
                guard s.running, s.generation == generation else { return nil }
                defer { s.next += 1 }
                return s.next
            }
            guard let value else { return }
            handler(value)
            tick(generation, handler)
        }
    }
}

public enum P1_06 {
    /// TODO: expose the monitor as an AsyncStream.
    ///  - start the monitor when the stream is created; each reading → `yield`
    ///  - STOP the monitor when the consumer stops listening (otherwise it runs forever: a leak)
    public static func heartRates(from monitor: LegacyHeartRateMonitor) -> AsyncStream<Int> {
        AsyncStream { continuation in
            // Called when the consumer goes away (loop break / task cancelled → .cancelled)
            // or after finish() (→ .finished). Either way: release the underlying resource.
            // Set it BEFORE starting, so a consumer that leaves instantly still stops the monitor.
            continuation.onTermination = { _ in
                monitor.stop()
            }
            monitor.start { bpm in
                continuation.yield(bpm)
            }
        }
    }

    public static func average(of values: some AsyncSequence<Int, Never>) async -> Double {
        var sum = 0
        var count = 0
        for await value in values { // suspends between elements; ends when the sequence returns nil
            sum += value
            count += 1
        }
        return count == 0 ? 0 : Double(sum) / Double(count)
    }
}
