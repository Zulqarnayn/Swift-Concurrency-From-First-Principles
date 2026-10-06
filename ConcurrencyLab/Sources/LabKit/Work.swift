import Foundation

// Three kinds of "taking time". Knowing which one you are doing is half of concurrency.
//
//   burnCPU(ms:)      CPU-bound. Thread is busy computing. Core is used.
//   blockThread(ms:)  Thread is parked by the OS (like a sync network call, semaphore.wait, sleep).
//                     Core is free, but the THREAD is held hostage.
//   suspend(ms:)      async. The *task* waits; the thread is returned to the pool to run other work.

/// Busy-loop for `ms` milliseconds. Simulates real computation (image decode, JSON parse, ...).
public func burnCPU(ms: Int) {
    let end = ContinuousClock.now + .milliseconds(ms)
    var x: UInt64 = 0
    while ContinuousClock.now < end {
        for i in 0..<1_000 { x &+= UInt64(i) &* 2_654_435_761 }
    }
    blackHole(x)
}

/// A FIXED amount of CPU work (unlike `burnCPU`, which spins until a deadline).
/// If the OS gives this thread only half a core, it takes twice as long. ~1 unit ≈ 1ms on a P-core (debug build).
public func crunch(units: Int) {
    var x: UInt64 = 0
    for _ in 0..<units {
        for i in 0..<10_000 { x &+= UInt64(i) &* 2_654_435_761 }
        blackHole(x)
    }
}

/// Park the current thread for `ms` milliseconds. Simulates blocking I/O or `semaphore.wait()`.
/// Calling this from async code is (usually) a bug — that's the point of several lessons.
public func blockThread(ms: Int) {
    usleep(useconds_t(ms * 1_000))
}

/// Suspend the current task for `ms` milliseconds without holding a thread.
/// Swallows cancellation on purpose so demos stay simple; real code should use `try await Task.sleep`.
public func suspend(ms: Int) async {
    try? await Task.sleep(for: .milliseconds(ms))
}

@inline(never)
public func blackHole<T>(_ x: T) {}
