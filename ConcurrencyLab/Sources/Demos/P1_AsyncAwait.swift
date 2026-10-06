import Foundation
import LabKit
import Puzzles

let phase1: [Demo] = [
    Demo("p1.01", "Suspension points: which thread are you on after await?", p1_01),
    Demo("p1.01b", "Blocking vs suspending inside async code", p1_01b),
    Demo("p1.02", "await frees the thread: a MainActor heartbeat", p1_02),
    Demo("p1.03", "The cooperative pool: fixed width, no explosion", p1_03),
    Demo("p1.03c", "Deadlocking the cooperative pool with a semaphore", optIn: true, p1_03c),
    Demo("p1.04", "Task: when does it start, where does it run, when does it end?", p1_04),
    Demo("p1.05", "Continuations: bridging callbacks to async", p1_05),
    Demo("p1.05b", "A continuation that is never resumed", p1_05b),
    Demo("p1.05c", "A continuation resumed twice (crashes)", optIn: true, p1_05c),
    Demo("p1.06", "AsyncStream: buffering, unicast, termination", p1_06),
    Demo("p1.07", "Errors: propagation, lost Task errors, typed throws", p1_07),
    Demo("p1.08", "Sync → async boundary: Task-per-event scrambles order", p1_08),
    Demo("p1.09", "Lab: legacy GCD feed vs async feed", p1_09),
    Demo("p1.10", "Async output puzzles", p1_10),
]

// MARK: - P1.01

@concurrent
func hopAround(_ name: String) async {
    trace("\(name): before await #1")
    await suspend(ms: 20)
    trace("\(name): after  await #1")
    await suspend(ms: 20)
    trace("\(name): after  await #2")
}

@MainActor
func stayOnMain(_ name: String) async {
    trace("\(name): before await #1")
    await suspend(ms: 20)
    trace("\(name): after  await #1")
    await suspend(ms: 20)
    trace("\(name): after  await #2")
}

func p1_01() async {
    trace("— three @concurrent functions running at the same time —")
    async let a: Void = hopAround("A")
    async let b: Void = hopAround("B")
    async let c: Void = hopAround("C")
    _ = await (a, b, c)

    trace("— one @MainActor function —")
    await stayOnMain("M")
}

@concurrent
func p1_01b() async {
    let n = ProcessInfo.processInfo.activeProcessorCount * 4
    let blocking = await measureMs {
        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<n { group.addTask { blockThread(ms: 100) } }
        }
    }
    trace("\(n) async tasks that BLOCK 100ms each:   \(blocking)ms")

    let suspending = await measureMs {
        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<n { group.addTask { await suspend(ms: 100) } }
        }
    }
    trace("\(n) async tasks that SUSPEND 100ms each: \(suspending)ms")
}

// MARK: - P1.02

@MainActor
func p1_02() async {
    let heartbeat = Task { // inherits @MainActor from this function
        var beat = 0
        while !Task.isCancelled {
            beat += 1
            trace("♥ \(beat)")
            await suspend(ms: 100)
        }
    }
    await suspend(ms: 50)

    trace("main actor: AWAITING 500ms...")
    await suspend(ms: 500)
    trace("main actor: done awaiting")

    trace("main actor: BLOCKING 500ms...")
    blockThread(ms: 500)
    trace("main actor: done blocking")

    await suspend(ms: 150)
    heartbeat.cancel()
}

// MARK: - P1.03

@concurrent
func p1_03() async {
    let cores = ProcessInfo.processInfo.activeProcessorCount

    let suspendThreads = ThreadSet()
    let suspendMs = await measureMs {
        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<64 {
                group.addTask {
                    suspendThreads.record()
                    await suspend(ms: 200)
                    suspendThreads.record()
                }
            }
        }
    }
    trace("64 tasks SUSPENDING 200ms: \(suspendThreads.count) threads, \(suspendMs)ms   (cores: \(cores))")

    let blockThreads = ThreadSet()
    let blockMs = await measureMs {
        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<64 {
                group.addTask {
                    blockThreads.record()
                    blockThread(ms: 200)
                }
            }
        }
    }
    trace("64 tasks BLOCKING 200ms:   \(blockThreads.count) threads, \(blockMs)ms")
    trace("compare P0.06: 64 blocking GCD blocks used 64 threads and ~300ms")
}

/// The loophole: `semaphore.wait()` is banned in async functions, but not in a sync helper they call.
func waitInSyncHelper(_ semaphore: DispatchSemaphore) {
    semaphore.wait()
}

@concurrent
func p1_03c() async {
    let waiters = ProcessInfo.processInfo.activeProcessorCount * 2
    // Watchdog on a plain OS thread: the cooperative pool is about to be completely stuck.
    Thread.detachNewThread {
        blockThread(ms: 3_000)
        trace("WATCHDOG: 3s and the signaller never ran. Every pool thread is parked in wait(). Deadlock.")
        exit(0)
    }
    let semaphore = DispatchSemaphore(value: 0)
    for i in 0..<waiters {
        Task {
            trace("task \(i): waiting for the signaller...")
            waitInSyncHelper(semaphore)
            trace("task \(i): released")
        }
    }
    await suspend(ms: 50)
    Task {
        trace("signaller: running → signal ×\(waiters)")
        for _ in 0..<waiters { semaphore.signal() }
    }
    await suspend(ms: 5_000)
}

// MARK: - P1.04

@MainActor
func p1_04() async {
    trace("— (a) when does a Task start? —")
    trace("A")
    let t = Task { trace("B (inside Task)") }
    trace("C")
    _ = await t.value

    trace("— (b) Task.immediate —")
    trace("A")
    let t2 = Task.immediate {
        trace("B (inside Task.immediate)")
        await suspend(ms: 10)
        trace("D (Task.immediate after its first await)")
    }
    trace("C")
    await t2.value

    trace("— (c) where does it run? (called from @MainActor) —")
    _ = await Task { trace("Task {}          runs here") }.value
    _ = await Task.detached { trace("Task.detached {} runs here") }.value

    trace("— (d) does a Task outlive the function that created it? —")
    startBackgroundWork()
    trace("startBackgroundWork() returned. The handle was dropped.")
    await suspend(ms: 150)
}

@MainActor
func startBackgroundWork() {
    Task {
        await suspend(ms: 100)
        trace("...still alive and finished its work 100ms later")
    }
}

// MARK: - P1.05

enum LegacyThermometer {
    /// Old callback API. Calls back once on a background queue — except for "Atlantis".
    static func fetch(city: String, completion: @escaping @Sendable (Int) -> Void) {
        DispatchQueue.global().asyncAfter(deadline: .now() + .milliseconds(30)) {
            trace("  legacy callback fires for \(city)")
            if city == "Atlantis" { return } // bug: drops the completion handler
            completion(city.count * 3)
        }
    }

    /// Calls back TWICE, like PHImageManager (degraded image first, then the full one).
    static func fetchTwice(city: String, completion: @escaping @Sendable (Int) -> Void) {
        DispatchQueue.global().asyncAfter(deadline: .now() + .milliseconds(10)) {
            completion(0)
            completion(city.count * 3)
        }
    }
}

func temperature(city: String) async -> Int {
    await withCheckedContinuation { continuation in
        trace("  inside withCheckedContinuation: starting legacy call")
        LegacyThermometer.fetch(city: city) { value in
            continuation.resume(returning: value)
        }
        trace("  inside withCheckedContinuation: body returned (task now suspended)")
    }
}

@MainActor
func p1_05() async {
    trace("calling temperature(city: \"Paris\")")
    let t = await temperature(city: "Paris")
    trace("got \(t)")
}

@MainActor
func p1_05b() async {
    trace("calling temperature(city: \"Atlantis\") with a 1s timeout")
    do {
        let t = try await withLabTimeout(seconds: 1) { await temperature(city: "Atlantis") }
        trace("got \(t)")
    } catch {
        trace("\(error)")
    }
    trace("(scroll up: the runtime printed a warning when the leaked continuation was destroyed)")
}

@MainActor
func p1_05c() async {
    trace("wrapping an API that calls back twice...")
    let t = await withCheckedContinuation { continuation in
        LegacyThermometer.fetchTwice(city: "Paris") { value in
            continuation.resume(returning: value)
        }
    }
    trace("got \(t)")
    await suspend(ms: 100)
}

// MARK: - P1.06

@MainActor
func p1_06() async {
    trace("— (a) a basic stream —")
    let (ticks, tickC) = AsyncStream.makeStream(of: Int.self)
    Task {
        for i in 1...3 {
            await suspend(ms: 20)
            trace("  producer: yield \(i)")
            tickC.yield(i)
        }
        tickC.finish()
    }
    for await t in ticks { trace("consumer got \(t)") }
    trace("loop ended because the producer called finish()")

    trace("— (b) bufferingNewest(2): yield 1,2,3 before anyone reads —")
    let (newest, newestC) = AsyncStream.makeStream(of: Int.self, bufferingPolicy: .bufferingNewest(2))
    for i in 1...3 { newestC.yield(i) }
    newestC.finish()
    var got: [Int] = []
    for await v in newest { got.append(v) }
    trace("consumer got \(got)")

    trace("— (c) two consumers, one stream —")
    let (shared, sharedC) = AsyncStream.makeStream(of: Int.self)
    let c1 = Task { var r: [Int] = []; for await v in shared { r.append(v); await suspend(ms: 1) }; return r }
    let c2 = Task { var r: [Int] = []; for await v in shared { r.append(v); await suspend(ms: 1) }; return r }
    await suspend(ms: 10)
    for i in 1...10 { sharedC.yield(i); await suspend(ms: 2) }
    sharedC.finish()
    let (r1, r2) = (await c1.value, await c2.value)
    trace("consumer 1: \(r1)")
    trace("consumer 2: \(r2)")

    trace("— (d) break out of the loop: who notices? —")
    let (kept, keptC) = AsyncStream.makeStream(of: Int.self)
    keptC.onTermination = { reason in trace("  onTermination(kept): \(reason)") }
    keptC.yield(1); keptC.yield(2); keptC.yield(3)
    for await v in kept {
        trace("got \(v)")
        if v == 2 { break }
    }
    trace("after break. producer yields again → \(keptC.yield(4))")
    trace("('kept' is still a live variable here)")
}

// MARK: - P1.07

struct BoomError: Error {}

func level3() async throws { await suspend(ms: 5); trace("level3 throws"); throw BoomError() }
func level2() async throws { trace("level2 calls level3"); try await level3(); trace("level2: unreachable") }
func level1() async throws { trace("level1 calls level2"); try await level2(); trace("level1: unreachable") }

@MainActor
func p1_07() async {
    trace("— (a) errors propagate up the await chain —")
    do { try await level1() } catch { trace("caught \(error) at the top") }

    trace("— (b) an error thrown inside a Task nobody awaits —")
    let dropped = Task {
        trace("task: throwing")
        throw BoomError()
    }
    await suspend(ms: 20)
    trace("...nothing was printed, logged or crashed. The error sits in the Task.")
    do { try await dropped.value } catch { trace("only `try await task.value` reveals it: \(error)") }

    trace("— (c) a catch-all that swallows cancellation —")
    let download = Task {
        do {
            try await Task.sleep(for: .seconds(5)) // "the download"
            trace("downloaded")
        } catch {
            trace("catch-all: 'Network failed, showing error alert!' — error was \(type(of: error))")
        }
    }
    await suspend(ms: 20)
    download.cancel() // the user navigated away
    await download.value
}

// MARK: - P1.08

@concurrent
func uploadSlowly(_ message: Int, log: EventLog) async {
    await suspend(ms: (message * 37) % 23)
    log.add("\(message)")
}

@concurrent
func p1_08() async {
    trace("— one Task per incoming message —")
    let log = EventLog()
    for message in 1...8 {
        Task { await uploadSlowly(message, log: log) }
    }
    await suspend(ms: 100)
    trace("server received: \(log.all.joined(separator: " "))")

    trace("— one long-lived consumer Task + AsyncStream —")
    let log2 = EventLog()
    let (inbox, inboxC) = AsyncStream.makeStream(of: Int.self)
    let consumer = Task {
        for await message in inbox { await uploadSlowly(message, log: log2) }
    }
    for message in 1...8 { inboxC.yield(message) } // sync, non-blocking, like a delegate callback
    inboxC.finish()
    await consumer.value
    trace("server received: \(log2.all.joined(separator: " "))")
}

// MARK: - P1.09

@concurrent
func p1_09() async {
    trace("see Sources/Exercises/P1_09_FeedLab.swift — run `swift test --filter P1_09` for this lab")
}

// MARK: - P1.10

func p1_10() async {
    for (name, run) in AsyncPuzzles.all {
        let answer = await run()
        trace("\(name): \(answer)")
    }
}
