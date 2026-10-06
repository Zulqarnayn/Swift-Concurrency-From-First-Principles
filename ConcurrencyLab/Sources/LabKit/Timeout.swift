import Foundation
import Synchronization

public struct LabTimeoutError: Error, CustomStringConvertible {
    public let seconds: Double
    public var description: String { "Timed out after \(seconds)s (hang / deadlock / never-resumed continuation?)" }
}

/// Run `operation`, but give up after `seconds`.
///
/// Used by tests so a buggy exercise (deadlock, leaked continuation) FAILS instead of hanging forever.
///
/// Note the design: a TaskGroup-based timeout would NOT work for hung code, because a task group
/// always waits for all its children before returning — and a hung child never finishes.
/// So this races an unstructured task against a timer and returns whichever finishes first.
/// (You'll build a proper structured `withTimeout` in Phase 3 and see exactly this trade-off.)
public func withLabTimeout<T: Sendable>(
    seconds: Double,
    _ operation: @escaping @Sendable () async throws -> T
) async throws -> T {
    let gate = OnceGate<Result<T, any Error>>()

    return try await withCheckedThrowingContinuation { (cont: CheckedContinuation<T, any Error>) in
        gate.install { result in cont.resume(with: result) }

        let work = Task {
            do { gate.fire(.success(try await operation())) }
            catch { gate.fire(.failure(error)) }
        }
        Task {
            try? await Task.sleep(for: .seconds(seconds))
            gate.fire(.failure(LabTimeoutError(seconds: seconds)))
            work.cancel()
        }
    }
}

/// Run BLOCKING code (locks, semaphores, `group.wait()`, joining threads) on a brand-new OS thread,
/// and await its result WITHOUT blocking the cooperative pool.
/// Returns nil if it hasn't finished after `timeoutSeconds` (the stuck thread is abandoned — fine for
/// deadlock demos and tests).
///
/// Why this exists: Swift Testing runs even *synchronous* @Test functions on the cooperative pool.
/// The first version of this course's tests blocked inside sync tests, starved the pool, and made
/// unrelated async tests time out at random. Exactly the bug P1.03 is about.
@discardableResult
public func onDedicatedThread<T: Sendable>(
    timeoutSeconds: Double = 30,
    _ body: @escaping @Sendable () -> T
) async -> T? {
    let gate = OnceGate<T?>()
    return await withCheckedContinuation { (cont: CheckedContinuation<T?, Never>) in
        gate.install { cont.resume(returning: $0) }
        Thread.detachNewThread { gate.fire(body()) }
        DispatchQueue.global().asyncAfter(deadline: .now() + timeoutSeconds) { gate.fire(nil) }
    }
}

/// Delivers exactly one value to a handler, no matter how many times `fire` is called.
final class OnceGate<Value: Sendable>: Sendable {
    private struct State {
        var handler: (@Sendable (Value) -> Void)?
        var pending: Value?
        var fired = false
    }
    private let state = Mutex(State())

    func install(_ handler: @escaping @Sendable (Value) -> Void) {
        let pending: Value? = state.withLock { s in
            s.handler = handler
            return s.pending
        }
        if let pending { handler(pending) }
    }

    func fire(_ value: Value) {
        let handler: (@Sendable (Value) -> Void)? = state.withLock { s in
            if s.fired { return nil }
            s.fired = true
            if s.handler == nil { s.pending = value }
            return s.handler
        }
        handler?(value)
    }
}
