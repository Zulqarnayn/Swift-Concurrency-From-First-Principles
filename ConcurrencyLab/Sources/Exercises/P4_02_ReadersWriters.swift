import Dispatch
import LabKit

// P4.02 — Readers–writers
// Lesson: lessons/P4-classics/02-readers-writers.md
// Test:   swift test --filter P4_02

/// Instrumentation (don't edit): detects readers overlapping writers, and measures read parallelism.
public final class RWProbe: Sendable {
    private struct State { var readers = 0; var writing = false; var readPeak = 0; var violations = 0 }
    private let state = Locked(State())
    public init() {}

    public func read<T>(_ body: () -> T) -> T {
        state.withLock { s in
            if s.writing { s.violations += 1 }
            s.readers += 1
            s.readPeak = max(s.readPeak, s.readers)
        }
        blockThread(ms: 1) // a slow-ish read, so overlap is observable
        let value = body()
        state.withLock { $0.readers -= 1 }
        return value
    }

    public func write(_ body: () -> Void) {
        state.withLock { s in
            if s.readers > 0 || s.writing { s.violations += 1 }
            s.writing = true
        }
        blockThread(ms: 1)
        body()
        state.withLock { $0.writing = false }
    }

    public var readPeak: Int { state.value.readPeak }
    public var violations: Int { state.value.violations }
}

/// The classic interview question: "make a thread-safe dictionary where reads run in parallel."
/// Readers may overlap each other. A writer must run ALONE (no readers, no other writer).
///
/// BUG: a serial queue is safe, but readers wait for each other for no reason.
/// TODO: use GCD's built-in readers–writer pattern. Keep `value(for:)` synchronous.
public final class RWCache: @unchecked Sendable {
    private var storage: [String: Int] = [:]
    private let queue = DispatchQueue(label: "RWCache")
    private let probe = RWProbe()

    public init() {}

    public func value(for key: String) -> Int? {
        queue.sync { probe.read { storage[key] } }
    }

    public func set(_ value: Int, for key: String) {
        queue.sync { probe.write { storage[key] = value } }
    }

    public var readPeak: Int { probe.readPeak }
    public var violations: Int { probe.violations }
}
