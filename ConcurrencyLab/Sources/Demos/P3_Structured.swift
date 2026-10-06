import Foundation
import LabKit
import Puzzles

let phase3: [Demo] = [
    Demo("p3.01", "Structured vs unstructured: who outlives whom?", p3_01),
    Demo("p3.02", "async let: parallel bindings, implicit cancel + await", p3_02),
    Demo("p3.03", "TaskGroup: completion order, errors cancel siblings", p3_03),
    Demo("p3.04", "Bounded concurrency: 40 jobs, unbounded vs sliding window", p3_04),
    Demo("p3.05", "DiscardingTaskGroup: a long-running server loop", p3_05),
    Demo("p3.06", "Cancellation is cooperative", p3_06),
    Demo("p3.07", "Cancellation propagates down the tree — not into Task {}", p3_07),
    Demo("p3.08", "Timeouts: racing a task against the clock", p3_08),
    Demo("p3.09", "Priority: inheritance, escalation, Task.yield", p3_09),
    Demo("p3.10", "@TaskLocal: context that flows down the task tree", p3_10),
    Demo("p3.11", "Unstructured tasks: start order and Task.immediate", p3_11),
    Demo("p3.12", "Structured concurrency output puzzles", p3_12),
]

// MARK: - P3.01

@concurrent
func fetchPart(_ name: String, ms: Int, log: EventLog) async {
    do {
        try await Task.sleep(for: .milliseconds(ms))
        log.add("\(name) finished")
        trace("  \(name) finished")
    } catch {
        log.add("\(name) cancelled")
        trace("  \(name) cancelled")
    }
}

func loadUnstructured(log: EventLog) async {
    Task { await fetchPart("A", ms: 50, log: log) }
    Task { await fetchPart("B", ms: 80, log: log) }
}

func loadStructured(log: EventLog) async {
    async let a: Void = fetchPart("A", ms: 50, log: log)
    async let b: Void = fetchPart("B", ms: 80, log: log)
    _ = await (a, b)
}

func p3_01() async {
    trace("— unstructured: Task {} children —")
    let log1 = EventLog()
    let t1 = await measureMs { await loadUnstructured(log: log1) }
    trace("loadUnstructured returned after \(t1)ms; children finished so far: \(log1.all)")
    await suspend(ms: 120)

    trace("— structured: async let children —")
    let log2 = EventLog()
    let t2 = await measureMs { await loadStructured(log: log2) }
    trace("loadStructured returned after \(t2)ms; children finished so far: \(log2.all)")

    trace("— cancel the PARENT 20ms in —")
    let log3 = EventLog(), log4 = EventLog()
    let u = Task { await loadUnstructured(log: log3); await suspend(ms: 200) }
    let s = Task { await loadStructured(log: log4) }
    await suspend(ms: 20)
    u.cancel(); s.cancel()
    await suspend(ms: 120)
    trace("unstructured children after parent cancel: \(log3.all)")
    trace("structured children after parent cancel:   \(log4.all)")
}

// MARK: - P3.02

@concurrent func slowValue(_ name: String, ms: Int) async throws -> String {
    do {
        try await Task.sleep(for: .milliseconds(ms))
    } catch {
        trace("  \(name): cancelled after being started")
        throw error
    }
    trace("  \(name): done")
    return name
}

/// Ignores cancellation: waits on a callback API that knows nothing about Swift tasks (see P1.05).
@concurrent func stubbornValue(ms: Int) async -> String {
    await withCheckedContinuation { (c: CheckedContinuation<Void, Never>) in
        DispatchQueue.global().asyncAfter(deadline: .now() + .milliseconds(ms)) { c.resume() }
    }
    trace("  stubborn child: finished anyway (isCancelled = \(Task.isCancelled))")
    return "stubborn"
}

struct FetchFailed: Error {}

@concurrent func failingValue(after ms: Int) async throws -> String {
    try await Task.sleep(for: .milliseconds(ms))
    trace("  failing child: throwing")
    throw FetchFailed()
}

func p3_02() async {
    trace("— sequential awaits —")
    let seq = await measureMs {
        _ = try? await slowValue("user", ms: 100)
        _ = try? await slowValue("news", ms: 100)
        _ = try? await slowValue("weather", ms: 100)
    }
    trace("sequential: \(seq)ms")

    trace("— async let —")
    let par = await measureMs {
        async let u = slowValue("user", ms: 100)
        async let n = slowValue("news", ms: 100)
        async let w = slowValue("weather", ms: 100)
        _ = try? await (u, n, w)
    }
    trace("async let: \(par)ms")

    trace("— an async let that is never awaited —")
    let unawaited = await measureMs {
        // `async let forgotten = …` and never using it gets a compiler warning; `_` says "on purpose".
        async let _ = slowValue("forgotten", ms: 300)
        trace("scope ends without awaiting the async let")
    }
    trace("scope took \(unawaited)ms to exit (child was cancelled — and honored it)")

    let unawaitedStubborn = await measureMs {
        async let _ = stubbornValue(ms: 300)
        trace("scope ends without awaiting a child that IGNORES cancellation")
    }
    trace("scope took \(unawaitedStubborn)ms to exit: the implicit await waited for it")

    trace("— one child throws; the other is slow —")
    let failMs = await measureMs {
        do {
            async let slow = slowValue("slow", ms: 500)
            async let bad = failingValue(after: 30)
            _ = try await (bad, slow)
        } catch {
            trace("caught \(error)")
        }
    }
    trace("failure surfaced after \(failMs)ms")
}

// MARK: - P3.03

func p3_03() async {
    trace("— 5 children with different durations —")
    let order = await withTaskGroup(of: Int.self) { group in
        for (i, ms) in [50, 10, 40, 20, 30].enumerated() {
            group.addTask {
                try? await Task.sleep(for: .milliseconds(ms))
                return i
            }
        }
        var finished: [Int] = []
        for await i in group { finished.append(i) }
        return finished
    }
    trace("added in order [0,1,2,3,4], results arrived in order \(order)")

    trace("— a ThrowingTaskGroup where child 2 fails —")
    do {
        try await withThrowingTaskGroup(of: String.self) { group in
            for i in 0..<4 {
                group.addTask {
                    if i == 2 { try await Task.sleep(for: .milliseconds(20)); throw FetchFailed() }
                    return try await slowValue("child \(i)", ms: 200)
                }
            }
            for try await value in group { trace("got \(value)") }
        }
    } catch {
        trace("group threw \(error) — and every sibling was cancelled first")
    }
}

// MARK: - P3.04

@concurrent func fakeDownload(_ i: Int, meter: ConcurrencyMeter) async -> Int {
    meter.enter()
    try? await Task.sleep(for: .milliseconds(20))
    meter.leave()
    return i
}

func p3_04() async {
    let unboundedMeter = ConcurrencyMeter()
    let unboundedMs = await measureMs {
        await withTaskGroup(of: Int.self) { group in
            for i in 0..<40 { group.addTask { await fakeDownload(i, meter: unboundedMeter) } }
        }
    }
    trace("unbounded: peak \(unboundedMeter.peak) at once, \(unboundedMs)ms")

    let boundedMeter = ConcurrencyMeter()
    let limit = 4
    let boundedMs = await measureMs {
        await withTaskGroup(of: Int.self) { group in
            var next = 0
            for _ in 0..<limit { // fill the window
                let i = next; next += 1
                group.addTask { await fakeDownload(i, meter: boundedMeter) }
            }
            while await group.next() != nil { // one finishes → start one more
                if next < 40 {
                    let i = next; next += 1
                    group.addTask { await fakeDownload(i, meter: boundedMeter) }
                }
            }
        }
    }
    trace("sliding window of \(limit): peak \(boundedMeter.peak) at once, \(boundedMs)ms")
}

// MARK: - P3.05

func p3_05() async {
    let (requests, inbox) = AsyncStream.makeStream(of: Int.self)
    let handled = CallCounter()
    let meter = ConcurrencyMeter()
    Task {
        for i in 1...6 { inbox.yield(i); await suspend(ms: 5) }
        inbox.finish()
    }
    await withDiscardingTaskGroup { group in
        for await _ in requests { // "accept loop"
            group.addTask {               // one child per connection; its result is discarded
                meter.enter()
                await suspend(ms: 30)
                handled.increment()
                meter.leave()
            }
        }
    }
    trace("server handled \(handled.count) requests, up to \(meter.peak) at once, then the stream ended and the group returned")
}

// MARK: - P3.06

@concurrent func countPrimesIgnoringCancellation(below n: Int) async -> Int {
    (2..<n).filter { k in (2..<k).allSatisfy { k % $0 != 0 } }.count
}

@concurrent func countPrimesCooperatively(below n: Int) async throws -> Int {
    var count = 0
    for k in 2..<n {
        if k % 500 == 0 { try Task.checkCancellation() } // a cheap check, every so often
        if (2..<k).allSatisfy({ k % $0 != 0 }) { count += 1 }
    }
    return count
}

func p3_06() async {
    trace("— CPU loop that never checks —")
    let t1 = Task { await countPrimesIgnoringCancellation(below: 12_000) }
    await suspend(ms: 10)
    let cancelAt1 = Trace.elapsedMs()
    t1.cancel()
    let r1 = await t1.value
    trace("cancel() at \(cancelAt1)ms; it ran to completion anyway at \(Trace.elapsedMs())ms → \(r1)")

    trace("— CPU loop that checks —")
    let t2 = Task { try await countPrimesCooperatively(below: 12_000) }
    await suspend(ms: 10)
    let cancelAt2 = Trace.elapsedMs()
    t2.cancel()
    let r2 = await t2.result
    trace("cancel() at \(cancelAt2)ms; stopped at \(Trace.elapsedMs())ms → \(r2)")

    trace("— withTaskCancellationHandler, task cancelled BEFORE it starts —")
    let t3 = Task {
        await withTaskCancellationHandler {
            trace("  operation: starts (isCancelled = \(Task.isCancelled))")
        } onCancel: {
            trace("  onCancel: runs")
        }
    }
    t3.cancel()
    _ = await t3.value
}

// MARK: - P3.07

func p3_07() async {
    let log = EventLog()
    let parent = Task {
        async let child: Void = fetchPart("async-let child", ms: 200, log: log)
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await fetchPart("group child", ms: 200, log: log) }
        }
        Task { await fetchPart("Task {} inside", ms: 200, log: log) }
        await child
    }
    await suspend(ms: 20)
    trace("cancelling the parent...")
    parent.cancel()
    await suspend(ms: 250)
    trace("results: \(log.all)")
}

// MARK: - P3.08

struct TimedOut: Error {}

/// Structured timeout: race the operation against a sleeping child; first one wins; cancel the other.
@concurrent
func raceTimeout<T: Sendable>(_ limit: Duration, _ operation: @escaping @Sendable () async throws -> T) async throws -> T {
    try await withThrowingTaskGroup(of: T.self) { group in
        group.addTask { try await operation() }
        group.addTask {
            try await Task.sleep(for: limit)
            throw TimedOut()
        }
        defer { group.cancelAll() }
        return try await group.next()!
    }
}

func p3_08() async {
    let fast = await measureMs { _ = try? await raceTimeout(.milliseconds(100)) { try await slowValue("fast op", ms: 20) } }
    trace("fast operation, 100ms limit → finished in \(fast)ms")

    var outcome = ""
    let slow = await measureMs {
        do { _ = try await raceTimeout(.milliseconds(100)) { try await slowValue("cooperative slow op", ms: 1_000) } }
        catch { outcome = "\(error)" }
    }
    trace("cooperative slow op, 100ms limit → \(outcome) after \(slow)ms")

    let stuck = await measureMs {
        do {
            _ = try await raceTimeout(.milliseconds(100)) {
                blockThread(ms: 600) // ignores cancellation completely
                return "done"
            }
        } catch { outcome = "\(error)" }
    }
    trace("NON-cooperative op, 100ms limit → \(outcome) after \(stuck)ms (!)")
}

// MARK: - P3.09

func p3_09() async {
    let low = Task(priority: .background) { () -> TaskPriority in
        await suspend(ms: 30)
        return Task.currentPriority
    }
    let inherited = await Task(priority: .userInitiated) {
        await Task { Task.currentPriority }.value
    }.value
    let detached = await Task(priority: .userInitiated) { () -> TaskPriority in
        let seen = Locked<TaskPriority?>(nil)
        let d = Task.detached { seen.value = Task.currentPriority }
        await suspend(ms: 20)        // read it BEFORE awaiting the detached task...
        let before = seen.value!
        await d.value                // ...because awaiting it would ESCALATE it to our priority
        return before
    }.value
    trace("child Task {} of a .userInitiated task: \(inherited)   (.userInitiated and .high are the same value)")
    trace("Task.detached inside a .userInitiated task: \(detached)")

    let escalated = await Task(priority: .high) { await low.value }.value
    trace("a .background task, awaited by a .high task, reports: \(escalated)")

    await p3_09_yield()
}

@MainActor
func p3_09_yield() async {
    for useYield in [false, true] {
        let ticks = Locked(0)
        let ticker = Task {
            while !Task.isCancelled {
                ticks.withLock { $0 += 1 }
                await Task.yield()
            }
        }
        await Task.yield()
        let before = ticks.value
        for _ in 0..<50 {
            burnCPU(ms: 2)               // a chunk of work on the main actor
            if useYield { await Task.yield() }
        }
        let during = ticks.value - before
        ticker.cancel()
        trace("100ms of main-actor work \(useYield ? "WITH" : "without") Task.yield → other main-actor task ran \(during) times")
    }
}

// MARK: - P3.10

enum RequestContext {
    @TaskLocal static var id = "none"
}

func p3_10() async {
    await RequestContext.$id.withValue("req-42") {
        trace("inside withValue:      \(RequestContext.id)")
        async let a = RequestContext.id
        let viaAsyncLet = await a
        let viaGroup = await withTaskGroup(of: String.self) { g in
            g.addTask { RequestContext.id }
            return await g.next()!
        }
        let viaTask = await Task { RequestContext.id }.value
        let viaDetached = await Task.detached { RequestContext.id }.value
        trace("async let child:       \(viaAsyncLet)")
        trace("TaskGroup child:       \(viaGroup)")
        trace("Task {}:               \(viaTask)")
        trace("Task.detached:         \(viaDetached)")
    }
    trace("after withValue:       \(RequestContext.id)")
}

// MARK: - P3.11

@MainActor
func p3_11() async {
    let mainLog = EventLog()
    var tasks: [Task<Void, Never>] = []
    for i in 1...6 { tasks.append(Task { mainLog.add("\(i)") }) }
    for t in tasks { await t.value }
    trace("6 × Task {} created on the main actor started in order: \(mainLog.all.joined(separator: " "))")

    var orders: Set<String> = []
    for _ in 0..<20 {
        let log = EventLog()
        await Task.detached {
            await withTaskGroup(of: Void.self) { _ in
                var ts: [Task<Void, Never>] = []
                for i in 1...6 { ts.append(Task { log.add("\(i)") }) }
                for t in ts { await t.value }
            }
        }.value
        orders.insert(log.all.joined(separator: " "))
    }
    trace("6 × Task {} created on a NONISOLATED task, 20 runs → \(orders.count) distinct start orders, e.g. \(orders.first!)")

    let log = EventLog()
    log.add("before")
    let t = Task.immediate { log.add("immediate body") }
    log.add("after")
    await t.value
    trace("Task.immediate: \(log.all)")
}

// MARK: - P3.12

func p3_12() async {
    for (name, run) in StructuredPuzzles.all {
        let answer = await run()
        trace("\(name): \(answer)")
    }
}
