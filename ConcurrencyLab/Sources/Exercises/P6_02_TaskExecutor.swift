import Dispatch
import Foundation
import LabKit

// P6.02 — Task executor preference
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
    public private(set) var threadID: UInt64 = 0

    public init() {}

    public func enqueue(_ job: consuming ExecutorJob) {
        let job = UnownedJob(job)
        DispatchQueue.global().async {
            job.runSynchronously(on: self.asUnownedTaskExecutor())
        }
    }
}
