import Combine
import Foundation
import LabKit
import Synchronization

let phase4: [Demo] = [
    Demo("p4.01", "Producer–consumer: two semaphores (threads) vs AsyncStream (no backpressure)", p4_01),
    Demo("p4.02", "Readers–writers: serial queue vs concurrent queue + barrier vs Mutex", p4_02),
    Demo("p4.03", "Dining philosophers: a lock deadlock vs an actor 'deadlock'", p4_03),
    Demo("p4.04", "Limiting width: fixed batches vs a sliding window", p4_04),
    Demo("p4.04c", "DispatchSemaphore as a limiter inside tasks: pool deadlock", optIn: true, p4_04c),
    Demo("p4.05", "Rate limiting the GCD way: semaphore + asyncAfter refills", p4_05),
    Demo("p4.06", "Keystrokes without debounce (stale results) and Combine's debounce", p4_06),
    Demo("p4.07", "The token-refresh race: every 401 refreshes", p4_07),
    Demo("p4.08", "Latch and barrier, GCD style: DispatchGroup and concurrentPerform", p4_08),
    Demo("p4.09", "LeetCode 1115 FooBar: the two-semaphore thread solution", p4_09),
    Demo("p4.10", "A naive image cache under load", p4_10),
    Demo("p4.11", "A naive retry loop that can't be cancelled", p4_11),
]

// MARK: - P4.01

@concurrent
func p4_01() async {
    // Classic (Dijkstra): `empty` counts free slots, `full` counts filled slots, a lock guards the buffer.
    let capacity = 3
    let empty = DispatchSemaphore(value: capacity)
    let full = DispatchSemaphore(value: 0)
    let buffer = Locked<[Int]>([])
    let maxSeen = Locked(0)
    let consumed = Locked<[Int]>([])
    await onDedicatedThread {
        onThreads(2) { role in
            if role == 0 {
                for i in 0..<20 {
                    empty.wait()                                   // block while full
                    buffer.withLock { $0.append(i) }
                    maxSeen.withLock { $0 = max($0, buffer.value.count) }
                    full.signal()
                }
            } else {
                for _ in 0..<20 {
                    full.wait()                                    // block while empty
                    let item = buffer.withLock { $0.removeFirst() }
                    consumed.withLock { $0.append(item) }
                    empty.signal()
                    usleep(1_000)                                  // slow consumer
                }
            }
        }
    }
    trace("threads + 2 semaphores: consumed \(consumed.value.count) in order: \(consumed.value == Array(0..<20)), max buffered \(maxSeen.value) (capacity \(capacity))")

    // AsyncStream: yield never waits. A fast producer just piles up elements.
    let (stream, continuation) = AsyncStream.makeStream(of: Int.self)
    let yielded = Atomic<Int>(0)
    Task {
        for i in 0..<500 {
            continuation.yield(i)
            yielded.add(1, ordering: .relaxed)
        }
        continuation.finish()
    }
    var taken = 0
    var maxBacklog = 0
    for await _ in stream {
        taken += 1
        maxBacklog = max(maxBacklog, yielded.load(ordering: .relaxed) - taken)
        await suspend(ms: 1)
    }
    trace("AsyncStream, fast producer + slow consumer: backlog reached \(maxBacklog) elements (no backpressure)")
}

// MARK: - P4.02

@concurrent
func p4_02() async {
    func run(_ name: String, read: @escaping @Sendable () -> Void) async {
        let ms = await measureMs {
            await onDedicatedThread { onThreads(8) { _ in for _ in 0..<100 { read() } } }
        }
        trace("\(name.padding(toLength: 36, withPad: " ", startingAt: 0)) 800 reads × 0.2ms: \(ms)ms")
    }

    let serial = DispatchQueue(label: "serial")
    await run("serial queue") { serial.sync { _ = usleep(200) } }

    let concurrent = DispatchQueue(label: "concurrent", attributes: .concurrent)
    await run("concurrent queue (+ barrier writes)") { concurrent.sync { _ = usleep(200) } }

    let mutex = Locked(0) // a Mutex in a box (a bare Mutex is non-copyable: can't be captured)
    await run("Mutex held during the read") { mutex.withLock { _ in _ = usleep(200) } }

    trace("(an actor serializes reads too: like the serial queue, but callers suspend instead of block)")
}

// MARK: - P4.03

actor DemoFork {
    private var held = false
    private var waiters: [CheckedContinuation<Void, Never>] = []
    func pickUp() async {
        guard held else { held = true; return }
        await withCheckedContinuation { waiters.append($0) }
    }
    func putDown() {
        if waiters.isEmpty { held = false } else { waiters.removeFirst().resume() }
    }
}

@concurrent
func p4_03() async {
    trace("— 5 threads, 5 NSLocks, everyone takes LEFT then RIGHT —")
    let locks = (0..<5).map { _ in NSLock() }
    let lockMeals = CallCounter()
    let finished = await onDedicatedThread(timeoutSeconds: 2) {
        onThreads(5) { i in
            for _ in 0..<10 {
                locks[i].lock()
                usleep(1_000)
                locks[(i + 1) % 5].lock()
                lockMeals.increment()
                locks[(i + 1) % 5].unlock()
                locks[i].unlock()
            }
        }
        return true
    }
    trace(finished == nil ? "DEADLOCK after \(lockMeals.count) meals: 5 threads blocked forever in lock()" : "finished (lucky timing)")

    trace("— 5 tasks, 5 fork ACTORS (async pickUp), same order —")
    let forks = (0..<5).map { _ in DemoFork() }
    let actorMeals = CallCounter()
    let hang = Task {
        await withTaskGroup(of: Void.self) { group in
            for i in 0..<5 {
                group.addTask {
                    for _ in 0..<10 {
                        await forks[i].pickUp()
                        await suspend(ms: 1)
                        await forks[(i + 1) % 5].pickUp()
                        actorMeals.increment()
                        await forks[(i + 1) % 5].putDown()
                        await forks[i].putDown()
                    }
                }
            }
        }
        return true
    }
    let outcome = try? await withLabTimeout(seconds: 1) { await hang.value }
    trace(outcome == nil ? "HANG after \(actorMeals.count) meals: every task is SUSPENDED waiting for a fork" : "finished")
    let healthy = await measureMs { await withTaskGroup(of: Void.self) { g in for _ in 0..<8 { g.addTask { await suspend(ms: 10) } } } }
    trace("...yet the cooperative pool is fine: 8 unrelated tasks just ran in \(healthy)ms. No thread is blocked.")
    trace("The app doesn't freeze. A feature silently never completes. That's how async deadlocks look in production.")
}

// MARK: - P4.04

@concurrent
func p4_04() async {
    let durations = (0..<24).map { [10, 10, 10, 90][$0 % 4] } // every 4th job is slow
    let batches = await measureMs {
        for start in stride(from: 0, to: durations.count, by: 4) {
            await withTaskGroup(of: Void.self) { group in
                for ms in durations[start..<start + 4] { group.addTask { await suspend(ms: ms) } }
            }
        }
    }
    trace("batches of 4 (each batch waits for its slowest job): \(batches)ms")

    let window = await measureMs {
        await withTaskGroup(of: Void.self) { group in
            var next = 0
            for _ in 0..<4 { let ms = durations[next]; next += 1; group.addTask { await suspend(ms: ms) } }
            while await group.next() != nil, next < durations.count {
                let ms = durations[next]; next += 1
                group.addTask { await suspend(ms: ms) }
            }
        }
    }
    trace("sliding window of 4 (a slot refills the moment it frees): \(window)ms")
}

@concurrent
func p4_04c() async {
    Thread.detachNewThread {
        blockThread(ms: 3_000)
        trace("WATCHDOG: nothing finished in 3s. Waiters block every pool thread; permit holders can't resume. Deadlock.")
        exit(0)
    }
    let semaphore = DispatchSemaphore(value: 4)
    trace("32 tasks, DispatchSemaphore(4) as a limiter, each holds its permit across an await...")
    await withTaskGroup(of: Void.self) { group in
        for _ in 0..<32 {
            group.addTask {
                waitInSyncHelper(semaphore)   // blocks a pool thread (P1.03's loophole)
                await suspend(ms: 50)         // needs a pool thread to RESUME
                semaphore.signal()
            }
        }
    }
    trace("never printed")
}

// MARK: - P4.05

@concurrent
func p4_05() async {
    // GCD: a semaphore holds the tokens; every acquisition schedules its own refill one interval later.
    // (Callers BLOCK in wait(), so this belongs on GCD threads, not in async code.)
    let tokens = DispatchSemaphore(value: 3)
    let times = Locked<[Int]>([])
    let start = ContinuousClock.now
    await onDedicatedThread {
        onThreads(9) { _ in
            tokens.wait()
            times.withLock { $0.append(ms(since: start)) }
            DispatchQueue.global().asyncAfter(deadline: .now() + .milliseconds(40)) { tokens.signal() }
        }
    }
    trace("capacity 3, refill 40ms → 9 callers got tokens at \(times.value.sorted()) ms")
    trace("(a 'sliding window' limiter: 3 per any 40ms. A token bucket refills smoothly instead.)")
}

// MARK: - P4.06

@concurrent
func p4_06() async {
    trace("— no debounce: every keystroke searches; slower (shorter) queries finish LAST —")
    let applied = Locked<[String]>([])
    let searches = CallCounter()
    for query in ["s", "sw", "swi", "swif", "swift"] {
        Task {
            searches.increment()
            await suspend(ms: 60 - query.count * 10) // shorter query = more matches = slower
            applied.withLock { $0.append(query) }
        }
        await suspend(ms: 8)
    }
    await suspend(ms: 120)
    trace("\(searches.count) searches; results applied in order \(applied.value) → the screen shows '\(applied.value.last!)' for 'swift'")

    trace("— Combine's debounce (the pre-async way) —")
    let subject = PassthroughSubject<String, Never>()
    let emitted = Locked<[String]>([])
    let cancellable = subject
        .debounce(for: .milliseconds(50), scheduler: DispatchQueue.global())
        .sink { value in emitted.withLock { $0.append(value) } }
    for query in ["s", "sw", "swi"] {
        subject.send(query)
        await suspend(ms: 10)
    }
    await suspend(ms: 120)
    trace("sent s, sw, swi 10ms apart → debounce emitted \(emitted.value)")
    withExtendedLifetime(cancellable) {}
}

// MARK: - P4.07

final class DemoAuthServer: Sendable {
    let generation = Atomic<Int>(1)
    let refreshes = CallCounter()
    func refresh() async -> String {
        refreshes.increment()
        await suspend(ms: 30)
        return "t\(generation.add(1, ordering: .relaxed).newValue)"
    }
    func fetch(token: String, latency: Int) async -> Bool {
        await suspend(ms: latency)
        return token == "t\(generation.load(ordering: .relaxed))"
    }
}

actor NaiveAuthClient {
    let server: DemoAuthServer
    var token = "t0"
    init(server: DemoAuthServer) { self.server = server }
    func send(latency: Int) async -> Bool {
        if await server.fetch(token: token, latency: latency) { return true }
        token = await server.refresh()                     // every 401 refreshes...
        return await server.fetch(token: token, latency: latency) // ...and rotates everyone else's token
    }
}

@concurrent
func p4_07() async {
    let server = DemoAuthServer()
    let client = NaiveAuthClient(server: server)
    let ok = await withTaskGroup(of: Bool.self) { group in
        for i in 0..<10 { group.addTask { await client.send(latency: 5 + (i % 5) * 10) } }
        var successes = 0
        for await success in group where success { successes += 1 }
        return successes
    }
    trace("10 concurrent requests with an expired token: \(server.refreshes.count) refreshes, \(ok)/10 succeeded")
}

// MARK: - P4.08

@concurrent
func p4_08() async {
    trace("— DispatchGroup as a latch: 'tell me when all 3 loaders reported' —")
    let group = DispatchGroup()
    for (name, ms) in [("config", 30), ("auth", 10), ("flags", 20)] {
        group.enter()
        DispatchQueue.global().asyncAfter(deadline: .now() + .milliseconds(ms)) {
            trace("  \(name) loaded")
            group.leave()
        }
    }
    await group.waitAsync()
    trace("all loaders done → launch")

    trace("— concurrentPerform as a barrier: each call returns only when ALL iterations finished —")
    for phase in 0..<3 {
        let threads = ThreadSet()
        DispatchQueue.concurrentPerform(iterations: 4) { _ in threads.record(); usleep(5_000) }
        trace("  phase \(phase) complete (\(threads.count) threads) → only now can phase \(phase + 1) start")
    }
}

// MARK: - P4.09

@concurrent
func p4_09() async {
    // LeetCode's intended answer: fooSem starts at 1, barSem at 0; each thread waits on its own, signals the other.
    let fooSem = DispatchSemaphore(value: 1)
    let barSem = DispatchSemaphore(value: 0)
    let out = Locked<[String]>([])
    await onDedicatedThread {
        onThreads(2) { role in
            for _ in 0..<5 {
                if role == 0 {
                    fooSem.wait(); out.withLock { $0.append("foo") }; barSem.signal()
                } else {
                    barSem.wait(); out.withLock { $0.append("bar") }; fooSem.signal()
                }
            }
        }
    }
    trace("two threads + two semaphores: \(out.value.joined())")
    trace("(in async code, wait() would block pool threads. The exercise uses an actor + continuations.)")
}

// MARK: - P4.10

actor NaiveImageCacheDemo {
    var cache: [Int: Data] = [:]
    let downloads = CallCounter()
    let meter = ConcurrencyMeter()
    func image(_ id: Int) async -> Data {
        if let hit = cache[id] { return hit }
        downloads.increment()
        meter.enter()
        await suspend(ms: 30)
        meter.leave()
        let data = Data(count: 50_000)
        cache[id] = data
        return data
    }
}

@concurrent
func p4_10() async {
    let cache = NaiveImageCacheDemo()
    await withTaskGroup(of: Void.self) { group in
        for request in 0..<120 { group.addTask { _ = await cache.image(request % 40) } } // a grid scrolling: lots of repeats
    }
    let count = await cache.cache.count
    trace("120 requests for 40 distinct images: \(cache.downloads.count) downloads, \(cache.meter.peak) in flight at once, \(count) images (\(count * 50)KB) kept forever")
}

// MARK: - P4.11

@concurrent
func p4_11() async {
    let attempts = CallCounter()
    let task = Task {
        for _ in 0..<5 {
            attempts.increment()
            trace("  attempt \(attempts.count) failed; backing off 40ms")
            try? await Task.sleep(for: .milliseconds(40)) // `try?` swallows the cancellation
        }
    }
    await suspend(ms: 50)
    trace("user left the screen: cancel()")
    task.cancel()
    await task.value
    trace("the loop ran all \(attempts.count) attempts anyway; each sleep returned instantly once cancelled")
}
