// FLAGS: -swift-version 6
// EXPECT: warning: mutation of captured var 'count' in concurrently-executing code
// EXPECT: error: sending value of non-Sendable type '() async -> ()' risks causing data races
//
// Lesson P0.02. The racy counter from Sources/UnsafeZone, compiled in Swift 6 mode.
// PREDICT before running `scripts/typecheck.sh ConcurrencyLab/Diagnostics/P0_02_racy_counter.swift`:
//   1. Does the GCD version compile?  Error, warning, or nothing?
//   2. Does the Task version compile?  Error, warning, or nothing?

import Dispatch

// Version 1: GCD
func racyWithGCD() -> Int {
    var count = 0
    let group = DispatchGroup()
    for _ in 0..<4 {
        DispatchQueue.global().async(group: group) {
            count += 1
        }
    }
    group.wait()
    return count
}

// Version 2: Swift concurrency
func racyWithTasks() {
    var count = 0
    for _ in 0..<4 {
        Task {
            count += 1
        }
    }
    print(count)
}
