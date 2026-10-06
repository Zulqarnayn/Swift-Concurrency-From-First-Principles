import Foundation
import LabKit

// P7.01 — SOLUTION. GCD & OperationQueue round
// Lesson: lessons/P7-interview/01-gcd-operationqueue.md
// Test:   swift test --filter P7_01

/// An OperationQueue-based import pipeline (the pre-async way many codebases still use).
/// For EACH file: download → parse → save, strictly in that order. Different files are independent.
/// At most 2 operations may run at the same time. `run` returns when everything finished (it blocks:
/// call it from a background thread, never main).
public final class ImportPipeline: @unchecked Sendable {
    public let log = EventLog()
    public let meter = ConcurrencyMeter()
    private let queue: OperationQueue = {
        let queue = OperationQueue()
        queue.maxConcurrentOperationCount = 2 // the width limit: GCD needs a semaphore for this (P0.06)
        return queue
    }()

    public init() {}

    public func run(files: [String]) {
        for file in files {
            let download = step("download", file)
            let parse = step("parse", file)
            let save = step("save", file)
            // Dependencies: an operation isn't READY until all its dependencies have finished.
            // (They can even span queues — something GCD has no equivalent for.)
            parse.addDependency(download)
            save.addDependency(parse)
            queue.addOperations([download, parse, save], waitUntilFinished: false)
        }
        queue.waitUntilAllOperationsAreFinished()
    }

    /// Stop the import: nothing that hasn't started yet may run.
    /// Cancelling marks every queued operation cancelled: a BlockOperation that hasn't started never runs
    /// its block. Running ones are NOT interrupted — like Swift tasks, cancellation is cooperative
    /// (a custom Operation would check `isCancelled` inside `main()`).
    /// Trap: cancelling ONE operation doesn't cancel its dependents — they become ready and run.
    /// That's why this cancels everything.
    public func cancelAll() {
        queue.cancelAllOperations()
    }

    private func step(_ name: String, _ file: String) -> Operation {
        BlockOperation { [self] in
            meter.enter()
            usleep(15_000)
            log.add("\(name) \(file)")
            meter.leave()
        }
    }
}
