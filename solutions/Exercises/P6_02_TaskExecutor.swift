import Dispatch
import Foundation
import LabKit

// P6.02 — SOLUTION. Task executor preference
// Lesson: lessons/P6-internals/02-task-executors.md
// Test:   swift test --filter P6_02

/// A TaskExecutor that runs every job on ONE dedicated OS thread — e.g. for a C library that is
/// thread-affine (all calls from the same thread), used from nonisolated async code via
/// `withTaskExecutorPreference(executor) { … }`.
///
/// TODO: right now jobs run on random GCD threads. Start one dedicated thread in `init`, record its id
/// in `threadID`, and make `enqueue` hand jobs to that thread (FIFO), which runs them one by one.
public final class DedicatedThreadExecutor: TaskExecutor, @unchecked Sendable {
    /// The OS thread id of the dedicated thread (see LabKit `currentThreadID()`).
    /// Written once in init, before anyone can enqueue → reads afterwards are safe (init happens-before use).
    public private(set) var threadID: UInt64 = 0

    private let pending = Locked<[UnownedJob]>([])
    private let available = DispatchSemaphore(value: 0) // counts queued jobs; the thread sleeps on it

    public init() {
        let started = DispatchSemaphore(value: 0)
        let box = Locked<UInt64>(0)
        Thread.detachNewThread { [pending, available] in
            box.value = currentThreadID()
            started.signal()
            // The run loop of a hand-made executor: wait for a job, run it, repeat. FIFO.
            // Blocking HERE is fine: this is our own thread, not the cooperative pool.
            while true {
                available.wait()
                let job = pending.withLock { $0.removeFirst() }
                job.runSynchronously(on: self.asUnownedTaskExecutor())
            }
            // (Never exits: a production version needs a shutdown path. Fine for a lab.)
        }
        started.wait()
        threadID = box.value
    }

    public func enqueue(_ job: consuming ExecutorJob) {
        let job = UnownedJob(job)
        pending.withLock { $0.append(job) }
        available.signal()
    }
}
