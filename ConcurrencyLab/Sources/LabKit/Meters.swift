import Foundation
import Synchronization

/// Records which OS threads ran some code. Thread-safe.
public final class ThreadSet: Sendable {
    private let ids = Mutex(Set<UInt64>())
    public init() {}

    /// Call from anywhere; remembers the current thread.
    public func record() {
        let id = currentThreadID()
        ids.withLock { _ = $0.insert(id) }
    }

    public var count: Int { ids.withLock { $0.count } }
}

/// Tracks how many operations are "in flight" right now and the maximum ever seen.
/// Use to prove a concurrency limit works (e.g. "never more than 3 downloads at once").
public final class ConcurrencyMeter: Sendable {
    private struct State { var current = 0; var peak = 0 }
    private let state = Mutex(State())
    public init() {}

    public func enter() {
        state.withLock {
            $0.current += 1
            $0.peak = max($0.peak, $0.current)
        }
    }

    public func leave() {
        state.withLock { $0.current -= 1 }
    }

    public var peak: Int { state.withLock { $0.peak } }
    public var current: Int { state.withLock { $0.current } }
}

/// Ordered, thread-safe list of events. Tests compare it with your predictions.
public final class EventLog: Sendable {
    private let events = Mutex<[String]>([])
    public init() {}

    public func add(_ event: String) {
        events.withLock { $0.append(event) }
    }

    public var all: [String] { events.withLock { $0 } }
}

/// Thread-safe counter, for counting calls in tests.
public final class CallCounter: Sendable {
    private let value = Mutex(0)
    public init() {}
    public func increment() { value.withLock { $0 += 1 } }
    public var count: Int { value.withLock { $0 } }
}

/// Measure wall-clock time of async work in milliseconds.
public func measureMs(_ work: () async throws -> Void) async rethrows -> Int {
    let start = ContinuousClock.now
    try await work()
    let d = ContinuousClock.now - start
    return Int(d.components.seconds * 1000 + d.components.attoseconds / 1_000_000_000_000_000)
}

/// Measure wall-clock time of sync work in milliseconds.
public func measureSyncMs(_ work: () throws -> Void) rethrows -> Int {
    let start = ContinuousClock.now
    try work()
    let d = ContinuousClock.now - start
    return Int(d.components.seconds * 1000 + d.components.attoseconds / 1_000_000_000_000_000)
}

/// Runs `body(i)` on `count` brand-new OS threads that all start at the same instant, then waits for all.
/// Unlike `concurrentPerform`, this gives real parallelism even when the system (or test runner) is busy —
/// which is what you want when trying to PROVOKE a race. Blocks the caller; use from sync code.
public func onThreads(_ count: Int, _ body: @escaping @Sendable (Int) -> Void) {
    let ready = DispatchGroup()
    let done = DispatchGroup()
    let startGate = DispatchSemaphore(value: 0)
    for i in 0..<count {
        ready.enter()
        done.enter()
        Thread.detachNewThread {
            ready.leave()
            startGate.wait()
            body(i)
            done.leave()
        }
    }
    ready.wait()
    for _ in 0..<count { startGate.signal() }
    done.wait()
}

/// A Sendable box around a Mutex. Use when a value must be shared by several closures/threads.
/// (A bare `Mutex` can't be captured by an escaping closure: it's non-copyable.)
public final class Locked<Value: Sendable>: Sendable {
    private let mutex: Mutex<Value>
    public init(_ value: Value) { mutex = Mutex(value) }
    public func withLock<R: Sendable>(_ body: (inout Value) -> R) -> R { mutex.withLock { body(&$0) } }
    public var value: Value {
        get { mutex.withLock { $0 } }
        set { mutex.withLock { $0 = newValue } }
    }
}
