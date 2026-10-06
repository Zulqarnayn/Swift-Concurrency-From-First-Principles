import Exercises
import Foundation
import LabKit
import Testing

private func elapsedMs(since start: ContinuousClock.Instant) -> Int {
    let d = ContinuousClock.now - start
    return Int(d.components.seconds * 1000 + d.components.attoseconds / 1_000_000_000_000_000)
}

@Suite struct P4_01Tests {
    @Test func backpressureAndOrder() async throws {
        let channel = BoundedChannel<Int>(capacity: 3)
        let producer = Task {
            for i in 0..<50 { await channel.send(i) }
            await channel.finish()
        }
        let received = try await withLabTimeout(seconds: 5) {
            var all: [Int] = []
            while let value = await channel.receive() {
                all.append(value)
                await suspend(ms: 1) // slow consumer
            }
            return all
        }
        await producer.value
        #expect(received == Array(0..<50))
        let peak = await channel.maxBuffered
        #expect(peak <= 3, "buffer grew to \(peak) with capacity 3")
    }

    @Test func sendSuspendsWhileFull() async throws {
        let channel = BoundedChannel<Int>(capacity: 2)
        let sent = CallCounter()
        let producer = Task {
            for i in 0..<4 {
                await channel.send(i)
                sent.increment()
            }
        }
        await suspend(ms: 30)
        #expect(sent.count == 2, "with capacity 2 and no consumer, only 2 sends may complete (got \(sent.count))")
        _ = await channel.receive()
        await suspend(ms: 20)
        #expect(sent.count == 3, "one receive frees one slot → exactly one more send completes")
        try await withLabTimeout(seconds: 2) {
            for _ in 0..<3 { _ = await channel.receive() }
        }
        await producer.value
    }

    @Test func manyProducersManyConsumers() async throws {
        let channel = BoundedChannel<Int>(capacity: 4)
        let received = try await withLabTimeout(seconds: 5) {
            await withTaskGroup(of: [Int].self) { group in
                group.addTask {
                    await withTaskGroup(of: Void.self) { producers in
                        for id in 0..<3 {
                            producers.addTask { for i in 0..<40 { await channel.send(id * 1000 + i) } }
                        }
                    }
                    await channel.finish()
                    return []
                }
                for _ in 0..<4 {
                    group.addTask {
                        var mine: [Int] = []
                        while let value = await channel.receive() { mine.append(value) }
                        return mine
                    }
                }
                var all: [Int] = []
                for await part in group { all += part }
                return all
            }
        }
        #expect(received.count == 120, "lost or duplicated elements: \(received.count)")
        #expect(Set(received).count == 120)
        #expect(await channel.maxBuffered <= 4)
    }
}

@Suite struct P4_02Tests {
    @Test func readersOverlapWritersAreExclusive() async {
        let cache = RWCache()
        await onDedicatedThread {
            onThreads(8) { t in
                for j in 0..<20 {
                    if j % 5 == 0 { cache.set(j, for: "k\(t)") } else { _ = cache.value(for: "k\(t)") }
                }
            }
        }
        #expect(cache.violations == 0, "a reader overlapped a writer (or two writers overlapped)")
        #expect(cache.readPeak > 1, "reads never ran in parallel (peak \(cache.readPeak))")
        let final = await onDedicatedThread { cache.value(for: "k3") }
        #expect(final == 15)
    }
}

@Suite struct P4_03Tests {
    @Test func everyoneEatsWithoutDeadlock() async throws {
        let table = DiningTable(seats: 5)
        try await withLabTimeout(seconds: 5) {
            await P4_03.dine(at: table, meals: 10)
        }
        #expect(table.meals.count == 50)
        #expect(table.violations.count == 0)
    }
}

@Suite struct P4_04Tests {
    @Test func limitsConcurrency() async throws {
        let semaphore = AsyncSemaphore(value: 3)
        let meter = ConcurrencyMeter()
        try await withLabTimeout(seconds: 5) {
            try await withThrowingTaskGroup(of: Void.self) { group in
                for _ in 0..<20 {
                    group.addTask {
                        try await semaphore.withPermit {
                            meter.enter()
                            await suspend(ms: 5)
                            meter.leave()
                        }
                    }
                }
                try await group.waitForAll()
            }
        }
        #expect(meter.peak == 3)
    }

    @Test func wakesWaitersInFIFOOrder() async throws {
        let semaphore = AsyncSemaphore(value: 0)
        let order = EventLog()
        var waiters: [Task<Void, any Error>] = []
        for i in 1...5 {
            waiters.append(Task {
                try await semaphore.wait()
                order.add("\(i)")
            })
            await suspend(ms: 5)
        }
        for _ in 1...5 {
            await semaphore.signal()
            await suspend(ms: 5)
        }
        let all = waiters
        try await withLabTimeout(seconds: 2) { for w in all { try await w.value } }
        #expect(order.all == ["1", "2", "3", "4", "5"])
    }

    @Test func cancelledWaiterThrowsAndTakesNoPermit() async throws {
        let semaphore = AsyncSemaphore(value: 0)
        let waiter = Task { try await semaphore.wait() }
        await suspend(ms: 10)
        waiter.cancel()
        let result = try await withLabTimeout(seconds: 1) { await waiter.result }
        #expect(throws: CancellationError.self) { try result.get() }

        await semaphore.signal()
        try await withLabTimeout(seconds: 1) {
            try await semaphore.wait() // the permit must still be there
        }
    }
}

@Suite struct P4_05Tests {
    @Test func burstThenSteadyRate() async throws {
        let bucket = TokenBucket(capacity: 3, refillInterval: .milliseconds(40))
        let start = ContinuousClock.now
        let times = Locked<[Int]>([])
        try await withLabTimeout(seconds: 3) {
            try await withThrowingTaskGroup(of: Void.self) { group in
                for _ in 0..<9 {
                    group.addTask {
                        try await bucket.acquire()
                        let t = elapsedMs(since: start)
                        times.withLock { $0.append(t) }
                    }
                }
                try await group.waitForAll()
            }
        }
        let t = times.value.sorted()
        // Timing margins are loose on purpose: under a full parallel test run the scheduler adds latency.
        // Correctness is the strict per-time-window check below.
        #expect(t[2] < 35, "the first 3 (the burst) should be immediate: \(t)")
        #expect(t[3] >= 30, "the 4th must wait for a refill: \(t)")
        #expect(t[8] >= 200 && t[8] < 400, "9 acquisitions ≈ 3 burst + 6 × 40ms: \(t)")
        for (i, ms) in t.enumerated() {
            #expect(i + 1 <= 3 + ms / 40, "\(i + 1) tokens handed out by \(ms)ms: too many")
        }
    }

    @Test func waitingAcquireIsCancellable() async throws {
        let bucket = TokenBucket(capacity: 1, refillInterval: .seconds(10))
        try await bucket.acquire()
        let waiter = Task { try await bucket.acquire() }
        await suspend(ms: 10)
        waiter.cancel()
        let result = try await withLabTimeout(seconds: 1) { await waiter.result }
        #expect(throws: CancellationError.self) { try result.get() }
    }
}

@Suite struct P4_06Tests {
    @Test @MainActor func searchesOnlyAfterAPause() async {
        let backend = SearchBackend()
        let model = DebouncedSearch(backend: backend, delay: .milliseconds(50))
        for query in ["s", "sw", "swi"] {
            model.queryChanged(query)
            await suspend(ms: 10)
        }
        await suspend(ms: 200)
        #expect(backend.queries.all == ["swi"], "searched for: \(backend.queries.all)")
        #expect(model.results == ["swi-result"])
        #expect(model.shown == ["swi"])
    }

    @Test @MainActor func newKeystrokeCancelsAnInFlightSearch() async {
        let backend = SearchBackend()
        let model = DebouncedSearch(backend: backend, delay: .milliseconds(30))
        model.queryChanged("x")
        await suspend(ms: 50) // debounce done (~30ms); the search for "x" is now in flight (40ms)
        model.queryChanged("xy")
        await suspend(ms: 200)
        #expect(backend.queries.all == ["x", "xy"])
        #expect(backend.cancelled.all == ["x"], "the in-flight search should have been cancelled")
        #expect(model.shown == ["xy"])
    }

    @Test func throttleRunsAtMostOncePerInterval() async {
        let throttler = Throttler(interval: .milliseconds(50))
        let runs = CallCounter()
        var ran: [Bool] = []
        for _ in 0..<10 {
            ran.append(await throttler.submit { runs.increment() })
            await suspend(ms: 10)
        }
        #expect(ran.first == true, "leading edge: the first submission runs")
        #expect((2...3).contains(runs.count), "10 submissions over ~100ms with a 50ms interval ran \(runs.count) times")
    }
}

@Suite struct P4_07Tests {
    @Test func concurrentUnauthorizedRequestsShareOneRefresh() async throws {
        let server = FakeAuthServer()
        let client = AuthClient(server: server)
        let results = try await withLabTimeout(seconds: 3) {
            try await withThrowingTaskGroup(of: String.self) { group in
                for i in 0..<10 {
                    let path = "/item/" + String(repeating: "x", count: i) // different latencies
                    group.addTask { try await client.send(path) }
                }
                var all: [String] = []
                for try await r in group { all.append(r) }
                return all
            }
        }
        #expect(results.count == 10)
        #expect(server.refreshCount.count == 1, "refreshed \(server.refreshCount.count) times")
    }

    @Test func refreshFailureReachesEveryWaiterThenNextCallRetries() async throws {
        let server = FakeAuthServer()
        server.setRefreshFails(true)
        let client = AuthClient(server: server)
        let failures = CallCounter()
        try await withLabTimeout(seconds: 3) {
            await withTaskGroup(of: Void.self) { group in
                for _ in 0..<5 {
                    group.addTask {
                        do { _ = try await client.send("/a") } catch is RefreshFailed { failures.increment() } catch {}
                    }
                }
            }
        }
        #expect(failures.count == 5, "every waiter must receive the refresh error")
        #expect(server.refreshCount.count == 1)

        server.setRefreshFails(false)
        let value = try await withLabTimeout(seconds: 2) { try await client.send("/a") }
        #expect(value == "data:/a")
        #expect(server.refreshCount.count == 2, "after a failed refresh, the next call must try again")
    }
}

@Suite struct P4_08Tests {
    @Test func latchReleasesOnlyAtZero() async throws {
        let latch = CountdownLatch(count: 3)
        let log = EventLog()
        let waiters = (0..<3).map { _ in
            Task {
                await latch.wait()
                log.add("released")
            }
        }
        for i in 1...3 {
            await suspend(ms: 10)
            log.add("countdown \(i)")
            await latch.countDown()
        }
        try await withLabTimeout(seconds: 2) { for w in waiters { await w.value } }
        #expect(Array(log.all.prefix(3)) == ["countdown 1", "countdown 2", "countdown 3"], "\(log.all)")
        #expect(log.all.filter { $0 == "released" }.count == 3)
        try await withLabTimeout(seconds: 1) { await latch.wait() } // already open: returns at once
    }

    @Test func barrierSeparatesEveryPhase() async throws {
        let barrier = CyclicBarrier(parties: 4)
        let log = EventLog()
        try await withLabTimeout(seconds: 5) {
            await withTaskGroup(of: Void.self) { group in
                for t in 0..<4 {
                    group.addTask {
                        for phase in 0..<3 {
                            await suspend(ms: (t * 7 + phase * 3) % 15)
                            log.add("arrive \(phase)")
                            await barrier.arriveAndWait()
                            log.add("pass \(phase)")
                        }
                    }
                }
            }
        }
        let events = log.all
        for phase in 0..<3 {
            let lastArrive = events.lastIndex(of: "arrive \(phase)")!
            let firstPass = events.firstIndex(of: "pass \(phase)")!
            #expect(lastArrive < firstPass, "phase \(phase): someone passed before everyone arrived")
        }
        #expect(events.filter { $0.hasPrefix("pass") }.count == 12)
    }
}

@Suite struct P4_09Tests {
    @Test func printInOrder() async throws {
        for _ in 0..<20 {
            let printer = InOrder()
            let log = EventLog()
            try await withLabTimeout(seconds: 2) {
                await withTaskGroup(of: Void.self) { group in
                    group.addTask { await printer.third { log.add("third") } }
                    group.addTask { await printer.second { log.add("second") } }
                    group.addTask { await printer.first { log.add("first") } }
                }
            }
            #expect(log.all == ["first", "second", "third"])
        }
    }

    @Test func fooBarAlternates() async throws {
        let fooBar = FooBar(n: 20)
        let log = EventLog()
        try await withLabTimeout(seconds: 2) {
            await withTaskGroup(of: Void.self) { group in
                group.addTask { await fooBar.bar { log.add("bar") } }
                group.addTask { await fooBar.foo { log.add("foo") } }
            }
        }
        #expect(log.all.joined() == String(repeating: "foobar", count: 20))
    }

    @Test func h2oReleasesWholeMolecules() async throws {
        let h2o = H2O()
        let log = EventLog()
        let atoms = (Array(repeating: "H", count: 20) + Array(repeating: "O", count: 10)).shuffled()
        try await withLabTimeout(seconds: 3) {
            await withTaskGroup(of: Void.self) { group in
                for atom in atoms {
                    group.addTask {
                        if atom == "H" { await h2o.hydrogen { log.add("H") } } else { await h2o.oxygen { log.add("O") } }
                    }
                }
            }
        }
        let out = log.all
        #expect(out.count == 30)
        for start in stride(from: 0, to: out.count, by: 3) {
            #expect(out[start..<min(start + 3, out.count)].sorted() == ["H", "H", "O"], "bad molecule at \(start): \(out)")
        }
    }
}

@Suite struct P4_10Tests {
    @Test func dedupesConcurrentRequests() async throws {
        let server = FakeImageServer()
        let pipeline = ImagePipeline(server: server, maxConcurrentDownloads: 4, cacheCapacity: 10)
        let images = try await withThrowingTaskGroup(of: Data.self) { group in
            for _ in 0..<10 { group.addTask { try await pipeline.image(7) } }
            var all: [Data] = []
            for try await d in group { all.append(d) }
            return all
        }
        #expect(Set(images) == [Data("image-7".utf8)])
        #expect(server.downloads.count == 1)
    }

    @Test func limitsConcurrentDownloads() async throws {
        let server = FakeImageServer()
        let pipeline = ImagePipeline(server: server, maxConcurrentDownloads: 4, cacheCapacity: 50)
        try await withLabTimeout(seconds: 3) {
            try await withThrowingTaskGroup(of: Data.self) { group in
                for id in 0..<20 { group.addTask { try await pipeline.image(id) } }
                for try await _ in group {}
            }
        }
        #expect(server.downloads.count == 20)
        #expect(server.meter.peak == 4, "peak downloads in flight: \(server.meter.peak)")
    }

    @Test func evictsLeastRecentlyUsed() async throws {
        let server = FakeImageServer()
        let pipeline = ImagePipeline(server: server, maxConcurrentDownloads: 4, cacheCapacity: 3)
        for id in [1, 2, 3] { _ = try await pipeline.image(id) }
        _ = try await pipeline.image(1)         // hit: 1 becomes most recently used
        _ = try await pipeline.image(4)         // full: evict the LRU, which is 2
        #expect(await pipeline.cachedIDs == [3, 1, 4])
        #expect(server.downloads.count == 4)
        _ = try await pipeline.image(2)         // evicted → downloaded again
        #expect(server.downloads.count == 5)
    }
}

@Suite struct P4_11Tests {
    struct Flaky: Error, Equatable { let attempt: Int }
    struct Fatal: Error {}

    @Test func retriesUntilSuccess() async throws {
        let attempts = CallCounter()
        var value = ""
        let elapsed = try await measureMs {
            value = try await P4_11.retry(maxAttempts: 5, initialDelay: .milliseconds(10)) {
                attempts.increment()
                if attempts.count < 3 { throw Flaky(attempt: attempts.count) }
                return "ok"
            }
        }
        #expect(value == "ok")
        #expect(attempts.count == 3)
        #expect(elapsed >= 30, "backoff should wait 10ms then 20ms (took \(elapsed)ms)")
    }

    @Test func givesUpWithTheLastError() async {
        let attempts = CallCounter()
        let elapsed = await measureMs {
            await #expect(throws: Flaky(attempt: 4)) {
                try await P4_11.retry(maxAttempts: 4, initialDelay: .milliseconds(10)) { () async throws -> Int in
                    attempts.increment()
                    throw Flaky(attempt: attempts.count)
                }
            }
        }
        #expect(attempts.count == 4)
        #expect(elapsed >= 70, "10 + 20 + 40ms of backoff expected (took \(elapsed)ms)")
    }

    @Test func nonRetryableErrorsAreThrownImmediately() async {
        let attempts = CallCounter()
        await #expect(throws: Fatal.self) {
            try await P4_11.retry(maxAttempts: 5, initialDelay: .milliseconds(10), shouldRetry: { !($0 is Fatal) }) { () async throws -> Int in
                attempts.increment()
                throw Fatal()
            }
        }
        #expect(attempts.count == 1)
    }

    @Test func cancellationErrorIsNeverRetried() async {
        let attempts = CallCounter()
        await #expect(throws: CancellationError.self) {
            try await P4_11.retry(maxAttempts: 5, initialDelay: .milliseconds(10)) { () async throws -> Int in
                attempts.increment()
                throw CancellationError()
            }
        }
        #expect(attempts.count == 1)
    }

    @Test func cancellingDuringBackoffStopsImmediately() async throws {
        let attempts = CallCounter()
        let task = Task {
            try await P4_11.retry(maxAttempts: 5, initialDelay: .seconds(1)) { () async throws -> Int in
                attempts.increment()
                throw Flaky(attempt: attempts.count)
            }
        }
        await suspend(ms: 30)
        task.cancel()
        var result: Result<Int, any Error>?
        let elapsed = try await measureMs {
            result = try await withLabTimeout(seconds: 2) { await task.result }
        }
        #expect(throws: CancellationError.self) { try result!.get() }
        #expect(elapsed < 100, "kept waiting \(elapsed)ms after cancel")
        #expect(attempts.count == 1)
    }
}

@Suite struct P4_12Tests {
    @Test func s1() { #expect(P4_12.s1 == .mainActor) }
    @Test func s2() { #expect(P4_12.s2 == .slidingWindow) }
    @Test func s3() { #expect(P4_12.s3 == .asyncSemaphore) }
    @Test func s4() { #expect(P4_12.s4 == .mutex) }
    @Test func s5() { #expect(P4_12.s5 == .singleFlight) }
    @Test func s6() { #expect(P4_12.s6 == .debounce) }
    @Test func s7() { #expect(P4_12.s7 == .throttle) }
    @Test func s8() { #expect(P4_12.s8 == .boundedChannel) }
    @Test func s9() { #expect(P4_12.s9 == .serialStream) }
    @Test func s10() { #expect(P4_12.s10 == .tokenBucket) }
    @Test func s11() { #expect(P4_12.s11 == .latch) }
    @Test func s12() { #expect(P4_12.s12 == .retryBackoff) }
}
