import Foundation
import LabKit
import Puzzles
import Synchronization
import UnsafeZone

let phase0: [Demo] = [
    Demo("p0.01", "Concurrency vs parallelism: same work, different shapes", p0_01),
    Demo("p0.02", "Data race: a lost-update counter", p0_02),
    Demo("p0.02b", "Data race on an Array: heap corruption", optIn: true, p0_02b),
    Demo("p0.03", "Atomicity: racy vs lock vs Atomic", p0_03),
    Demo("p0.04", "Race condition WITHOUT a data race (Swift 6 compiles it happily)", p0_04),
    Demo("p0.05", "Deadlock: lock-order inversion", p0_05),
    Demo("p0.05b", "Deadlock: serial queue sync onto itself (crashes)", optIn: true, p0_05b),
    Demo("p0.05c", "Deadlock: re-locking a non-recursive Mutex (crashes)", optIn: true, p0_05c),
    Demo("p0.06", "GCD thread explosion: blocking vs CPU work", p0_06),
    Demo("p0.07", "Completion handlers: three ways to break the contract", p0_07),
    Demo("p0.08", "GCD output puzzles", p0_08),
]

// MARK: - P0.01

@concurrent
func p0_01() async {
    let cores = ProcessInfo.processInfo.activeProcessorCount
    trace("activeProcessorCount = \(cores)")

    // 1. Serial: one thread does all 8 units of work.
    let serial = measureSyncMs {
        for _ in 0..<8 { burnCPU(ms: 100) }
    }
    trace("8 × 100ms CPU work, one thread:                \(serial)ms")

    // 2. Parallel: concurrentPerform spreads iterations over all cores.
    let parallel = measureSyncMs {
        DispatchQueue.concurrentPerform(iterations: 8) { _ in burnCPU(ms: 100) }
    }
    trace("8 × 100ms CPU work, concurrentPerform:         \(parallel)ms")

    // 3. More work than cores.
    let over = measureSyncMs {
        DispatchQueue.concurrentPerform(iterations: 32) { _ in burnCPU(ms: 100) }
    }
    trace("32 × 100ms CPU work, concurrentPerform:        \(over)ms")

    // 4. Concurrency without (much) parallelism: 16 threads, all "in progress" at once, 8 cores.
    //    crunch() does a FIXED amount of work, so a thread that gets less CPU time finishes later.
    let alone = measureSyncMs { crunch(units: 200) }
    trace("crunch(units: 200) alone on one thread:         \(alone)ms")
    let starts = EventLog()
    let ends = EventLog()
    let group = DispatchGroup()
    let t0 = ContinuousClock.now
    for i in 0..<16 {
        group.enter()
        Thread.detachNewThread {
            starts.add("\(i)@\(ms(since: t0))")
            crunch(units: 200)
            ends.add("\(i)@\(ms(since: t0))")
            group.leave()
        }
    }
    await group.waitAsync()
    trace("16 threads × crunch(200): start times (ms) \(starts.all.map { $0.split(separator: "@")[1] }.joined(separator: ","))")
    trace("16 threads × crunch(200): end times   (ms) \(ends.all.map { $0.split(separator: "@")[1] }.joined(separator: ","))")
}

func ms(since start: ContinuousClock.Instant) -> Int {
    let d = ContinuousClock.now - start
    return Int(d.components.seconds * 1000 + d.components.attoseconds / 1_000_000_000_000_000)
}

// MARK: - P0.02

@concurrent
func p0_02() async {
    for run in 1...5 {
        let result = Racy.counter(threads: 4, increments: 100_000)
        trace("run \(run): expected 400000, got \(result)  (lost \(400_000 - result) updates)")
    }
    trace("Now run with Thread Sanitizer:  swift run --sanitize=thread lab p0.02")
}

@concurrent
func p0_02b() async {
    trace("8 threads appending 100_000 Ints each to ONE Array...")
    let count = Racy.arrayAppend(threads: 8, appends: 100_000)
    trace("survived! count = \(count) (expected 800000). Run it a few times.")
}

// MARK: - P0.03

/// Lock-protected counter. `@unchecked Sendable` = "compiler, trust me, I synchronize by hand."
final class NSLockCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var value = 0
    func increment() { lock.lock(); value += 1; lock.unlock() }
    var current: Int { lock.lock(); defer { lock.unlock() }; return value }
}

/// Atomic counter: the CPU does load+add+store as ONE indivisible instruction.
final class AtomicCounter: Sendable {
    private let value = Atomic<Int>(0)
    func increment() { value.add(1, ordering: .relaxed) }
    var current: Int { value.load(ordering: .relaxed) }
}

@concurrent
func p0_03() async {
    let threads = 4, n = 1_000_000
    var racy = 0
    let racyMs = measureSyncMs { racy = Racy.counter(threads: threads, increments: n) }
    trace("racy:   \(racy)  in \(racyMs)ms")

    let locked = NSLockCounter()
    let lockMs = measureSyncMs {
        DispatchQueue.concurrentPerform(iterations: threads) { _ in for _ in 0..<n { locked.increment() } }
    }
    trace("NSLock: \(locked.current)  in \(lockMs)ms")

    let atomic = AtomicCounter()
    let atomicMs = measureSyncMs {
        DispatchQueue.concurrentPerform(iterations: threads) { _ in for _ in 0..<n { atomic.increment() } }
    }
    trace("Atomic: \(atomic.current)  in \(atomicMs)ms")
}

// MARK: - P0.04

/// Every single access is protected by a Mutex. Zero data races. Swift 6 is happy.
/// And yet...
final class SplitLockAccount: Sendable {
    private let balance = Mutex(500)
    var current: Int { balance.withLock { $0 } }
    func set(_ value: Int) { balance.withLock { $0 = value } }
}

@concurrent
func p0_04() async {
    let account = SplitLockAccount()
    let approved = CallCounter()
    DispatchQueue.concurrentPerform(iterations: 10) { i in
        if account.current >= 100 {            // check   (critical section #1)
            blockThread(ms: 1)                  // ...some latency (logging, a network call)
            account.set(account.current - 100)  // act     (critical sections #2 and #3)
            approved.increment()
        }
    }
    trace("start balance: 500, 10 people withdraw 100 each")
    trace("withdrawals approved: \(approved.count)")
    trace("final balance:        \(account.current)")
    trace("money handed out:     \(approved.count * 100)")
}

// MARK: - P0.05

@concurrent
func p0_05() async {
    let a = NSLock(), b = NSLock()
    trace("T1 takes A then B. T2 takes B then A. Waiting up to 2s...")
    let finished = await onDedicatedThread(timeoutSeconds: 2) {
        let group = DispatchGroup()
        group.enter()
        group.enter()
        Thread.detachNewThread {
            a.lock(); trace("T1: holds A, wants B")
            blockThread(ms: 50)
            b.lock(); trace("T1: got both")
            b.unlock(); a.unlock()
            group.leave()
        }
        Thread.detachNewThread {
            b.lock(); trace("T2: holds B, wants A")
            blockThread(ms: 50)
            a.lock(); trace("T2: got both")
            a.unlock(); b.unlock()
            group.leave()
        }
        blockThread(ms: 10)
        group.wait()
        return true
    }
    if finished == nil {
        trace("DEADLOCK. Nobody progressed for 2s. Both threads are parked forever.")
    } else {
        trace("finished — lucky timing this time")
    }
}

@concurrent
func p0_05b() async {
    let queue = DispatchQueue(label: "serial")
    trace("queue.sync { queue.sync { ... } } — the inner block waits for the outer, which waits for the inner")
    queue.sync {
        queue.sync { _ = trace("inner — you will never see this") }
    }
}

@concurrent
func p0_05c() async {
    let mutex = Mutex(0)
    trace("mutex.withLock { mutex.withLock { ... } } on the same thread")
    mutex.withLock { _ in
        mutex.withLock { _ in _ = trace("inner — you will never see this") }
    }
}

// MARK: - P0.06

@concurrent
func p0_06() async {
    let cores = ProcessInfo.processInfo.activeProcessorCount

    let blockingThreads = ThreadSet()
    let group = DispatchGroup()
    let blockingMs = await measureMs {
        for _ in 0..<64 {
            DispatchQueue.global().async(group: group) {
                blockingThreads.record()
                blockThread(ms: 300)        // like a sync network call or semaphore.wait()
            }
        }
        await group.waitAsync()
    }
    trace("64 BLOCKING jobs on a global queue: \(blockingThreads.count) threads, \(blockingMs)ms   (cores: \(cores))")

    let cpuThreads = ThreadSet()
    let group2 = DispatchGroup()
    let cpuMs = await measureMs {
        for _ in 0..<64 {
            DispatchQueue.global().async(group: group2) {
                cpuThreads.record()
                burnCPU(ms: 20)
            }
        }
        await group2.waitAsync()
    }
    trace("64 CPU jobs on a global queue:      \(cpuThreads.count) threads, \(cpuMs)ms")
}

// MARK: - P0.07

enum LegacyLoader {
    /// Buggy legacy API. Contract (in the docs nobody reads): "completion called once, on main".
    static func load(_ id: String, completion: @escaping @Sendable (String) -> Void) {
        DispatchQueue.global().asyncAfter(deadline: .now() + .milliseconds(20)) {
            if id.isEmpty { return }                         // forgot to call completion
            if id == "dup" { completion("cached \(id)") }     // forgot `return` → called twice
            completion("fresh \(id)")                         // and never on main
        }
    }
}

@concurrent
func p0_07() async {
    for id in ["42", "dup", ""] {
        let calls = CallCounter()
        LegacyLoader.load(id) { value in
            calls.increment()
            trace("  id=\"\(id)\" callback #\(calls.count): \(value)  queue='\(currentQueueLabel())'")
        }
        await suspend(ms: 100)
        trace("id=\"\(id)\" → callback called \(calls.count) time(s)")
    }
}

// MARK: - P0.08

@concurrent
func p0_08() async {
    for (name, run) in GCDPuzzles.all {
        trace("\(name): \(run())")
    }
}
