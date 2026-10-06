// FLAGS: -swift-version 6 -enable-upcoming-feature NonisolatedNonsendingByDefault
// EXPECT: error: instance method 'wait' is unavailable from asynchronous contexts; Await a Task handle instead
// EXPECT: error: instance method 'wait' is unavailable from asynchronous contexts; Use a TaskGroup instead
// EXPECT: error: class method 'sleep' is unavailable from asynchronous contexts; Use Task.sleep(until:clock:) instead.
// EXPECT: error: instance method 'lock' is unavailable from asynchronous contexts; Use async-safe scoped locking instead
//
// Lesson P1.03. Which of these blocking calls does the compiler catch? Which slip through?
//   scripts/typecheck.sh ConcurrencyLab/Diagnostics/P1_03_blocking_in_async.swift

import Foundation

func blockingInAsync() async {
    let semaphore = DispatchSemaphore(value: 0)
    semaphore.wait()                        // A

    let group = DispatchGroup()
    group.wait()                            // B

    Thread.sleep(forTimeInterval: 1)        // C

    usleep(1_000_000)                       // D

    let lock = NSLock()
    lock.lock()                             // E
    lock.unlock()

    _ = try? Data(contentsOf: URL(string: "https://example.com")!)   // F: synchronous network I/O

    waitForever(semaphore)                  // G
}

func waitForever(_ semaphore: DispatchSemaphore) {
    semaphore.wait()                        // H: same call as A, inside a sync helper
}
