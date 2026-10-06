import Dispatch
import Exercises
import Foundation
import LabKit
import Puzzles
import Synchronization
import Testing

// MARK: - P6.01

@Suite struct P6_01Tests {
    @Test func everyActorMethodRunsOnTheLegacyQueue() async {
        let db = QueueBoundDatabase()
        let labels = await withTaskGroup(of: String.self) { group in
            for i in 0..<50 { group.addTask { await db.insert("row \(i)") } }
            group.addTask { await db.count() }
            var all: [String] = []
            for await label in group { all.append(label) }
            return all
        }
        #expect(Set(labels) == ["legacy.db.queue"], "actor code ran on: \(Set(labels))")
        #expect(db.legacy.violations.count == 0)
    }
}

// MARK: - P6.02

@Suite struct P6_02Tests {
    @Test func allPreferredWorkRunsOnTheDedicatedThread() async {
        let executor = DedicatedThreadExecutor()
        let threads = await withTaskExecutorPreference(executor) {
            await withTaskGroup(of: [UInt64].self) { group in
                for _ in 0..<8 {
                    group.addTask {
                        var seen = [currentThreadID()]
                        await suspend(ms: 2)
                        seen.append(currentThreadID())
                        return seen
                    }
                }
                var all: [UInt64] = []
                for await ids in group { all += ids }
                return all
            }
        }
        #expect(executor.threadID != 0, "threadID was never recorded")
        #expect(Set(threads) == [executor.threadID], "jobs ran on \(Set(threads).count) different threads")
    }
}

// MARK: - P6.03 (measures this machine, then grades your estimates)

private func residentBytes() -> Int {
    var info = mach_task_basic_info()
    var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size / MemoryLayout<natural_t>.size)
    _ = withUnsafeMutablePointer(to: &info) {
        $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
            task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
        }
    }
    return Int(info.resident_size)
}

private final class Parking: Sendable {
    private let waiting = Mutex<[CheckedContinuation<Void, Never>]>([])
    func park() async { await withCheckedContinuation { c in waiting.withLock { $0.append(c) } } }
    func releaseAll() {
        let all = waiting.withLock { w in defer { w = [] }; return w }
        for c in all { c.resume() }
    }
}

private func memoryBucket(_ bytes: Int) -> MemoryBucket {
    switch bytes {
    case ..<256: .under256Bytes
    case ..<4_096: .from256BytesTo4KB
    case ..<65_536: .from4KBTo64KB
    default: .over64KB
    }
}

private func timeBucket(nanoseconds: Double) -> TimeBucket {
    switch nanoseconds {
    case ..<100: .under100ns
    case ..<100_000: .from100nsTo100us
    case ..<10_000_000: .from100usTo10ms
    default: .over10ms
    }
}

@MainActor private func mainNoop() {}

private actor IdleActor {
    func noop() {}
}

@concurrent private func measureHops(_ k: Int) async -> (mainNs: Double, actorNs: Double) {
    let clock = ContinuousClock()
    var start = clock.now
    for _ in 0..<k { await mainNoop() }
    let main = clock.now - start
    let actor = IdleActor()
    start = clock.now
    for _ in 0..<k { await actor.noop() }
    let actorTime = clock.now - start
    func ns(_ d: Duration) -> Double { Double(d.components.seconds) * 1e9 + Double(d.components.attoseconds) / 1e9 }
    return (ns(main) / Double(k), ns(actorTime) / Double(k))
}

@Suite(.serialized) struct P6_03Tests {
    @Test func suspendedTaskMemory() async {
        let parking = Parking()
        let n = 50_000
        let before = residentBytes()
        var tasks: [Task<Void, Never>] = []
        for _ in 0..<n { tasks.append(Task { await parking.park() }) }
        await suspend(ms: 300)
        let perTask = (residentBytes() - before) / n
        parking.releaseAll()
        for t in tasks { await t.value }
        #expect(P6_03.suspendedTaskMemory == memoryBucket(perTask), "measured ≈ \(perTask) bytes per suspended task")
    }

    @Test func threadStackReservation() {
        #expect(P6_03.threadStackReservation == .over64KB, "secondary threads reserve 512KB of stack")
    }

    @Test func taskCreateAndAwait() async {
        let k = 20_000
        let clock = ContinuousClock()
        let start = clock.now
        for _ in 0..<k { await Task {}.value }
        let d = clock.now - start
        let ns = (Double(d.components.seconds) * 1e9 + Double(d.components.attoseconds) / 1e9) / Double(k)
        #expect(P6_03.taskCreateAndAwait == timeBucket(nanoseconds: ns), "measured ≈ \(Int(ns))ns per Task create+await")
    }

    @Test func hops() async {
        let (mainNs, actorNs) = await measureHops(3_000)
        #expect(P6_03.mainActorRoundTrip == timeBucket(nanoseconds: mainNs), "measured ≈ \(Int(mainNs))ns per MainActor round trip")
        let ratio = mainNs / max(actorNs, 1)
        let bucket: Ratio = ratio < 0.8 ? .cheaper : ratio < 3 ? .aboutTheSame : ratio < 30 ? .from3xTo30x : .over30x
        #expect(P6_03.mainHopVersusActorCall == bucket, "measured: MainActor round trip ≈ \(Int(ratio))× an idle actor call")
    }
}

// MARK: - P6.04

@Suite struct P6_04Tests {
    @Test @MainActor func batchesMainActorUpdates() async {
        let progress = ImportProgress()
        await P6_04.importAll(Array(0..<5_000), progress: progress)
        #expect(progress.processed == 5_000)
        #expect(progress.history.count <= 20, "\(progress.history.count) main-actor updates")
        #expect(progress.history == progress.history.sorted(), "progress went backwards")
        var previous = 0
        for value in progress.history {
            #expect(value - previous <= 500, "a gap of \(value - previous) records (> 10%) between UI updates")
            previous = value
        }
    }

    @Test @MainActor func smallImports() async {
        let progress = ImportProgress()
        await P6_04.importAll(Array(0..<7), progress: progress)
        #expect(progress.processed == 7)
        #expect(progress.history.count <= 20)
    }
}

// MARK: - P6.05

@Suite struct P6_05Tests {
    @Test func q1() { #expect(P6_05.q1 == .guaranteed) }
    @Test func q2() { #expect(P6_05.q2 == .notGuaranteed) }
    @Test func q3() { #expect(P6_05.q3 == .guaranteed) }
    @Test func q4() { #expect(P6_05.q4 == .guaranteed) }
    @Test func q5() { #expect(P6_05.q5 == .guaranteed) }
    @Test func q6() { #expect(P6_05.q6 == .guaranteed) }
    @Test func q7() { #expect(P6_05.q7 == .notGuaranteed) }
    @Test func q8() { #expect(P6_05.q8 == .guaranteed) }
}

// MARK: - P6.06

@Suite struct P6_06Tests {
    @Test func eventsArriveInOrder() async throws {
        for _ in 0..<10 {
            let sink = await EventSink()
            await Task.detached {
                for event in 0..<40 { P6_06.forward(event, to: sink) }
            }.value
            let deadline = ContinuousClock.now + .seconds(2)
            while await sink.events.count < 40 && ContinuousClock.now < deadline { await suspend(ms: 5) }
            let events = await sink.events
            #expect(events == Array(0..<40), "out of order: \(events)")
        }
    }
}

// MARK: - P6.07

@Suite struct P6_07Tests {
    @Test func proposals() {
        #expect(P6_07.asyncAwait == 296)
        #expect(P6_07.actors == 306)
        #expect(P6_07.sendable == 302)
        #expect(P6_07.structuredConcurrency == 304)
        #expect(P6_07.asyncLet == 317)
        #expect(P6_07.globalActors == 316)
        #expect(P6_07.continuations == 300)
        #expect(P6_07.taskLocals == 311)
        #expect(P6_07.customActorExecutors == 392)
        #expect(P6_07.isolatedDeinit == 371)
        #expect(P6_07.typedThrows == 413)
        #expect(P6_07.regionBasedIsolation == 414)
        #expect(P6_07.taskExecutorPreference == 417)
        #expect(P6_07.sendingKeyword == 430)
        #expect(P6_07.isolatedAnyFunctionTypes == 431)
        #expect(P6_07.mutex == 433)
        #expect(P6_07.nonisolatedNonsendingByDefault == 461)
        #expect(P6_07.defaultActorIsolation == 466)
        #expect(P6_07.isolatedConformances == 470)
        #expect(P6_07.taskImmediate == 472)
    }
}

// MARK: - P7.01

@Suite struct P7_01Tests {
    @Test func stepsInOrderWithLimit() async {
        let pipeline = ImportPipeline()
        let files = ["a", "b", "c", "d"]
        await onDedicatedThread { pipeline.run(files: files) }
        let log = pipeline.log.all
        #expect(log.count == 12)
        for file in files {
            let d = log.firstIndex(of: "download \(file)")
            let p = log.firstIndex(of: "parse \(file)")
            let s = log.firstIndex(of: "save \(file)")
            #expect(d != nil && p != nil && s != nil && d! < p! && p! < s!, "\(file): wrong order in \(log)")
        }
        #expect(pipeline.meter.peak == 2, "peak concurrent operations: \(pipeline.meter.peak)")
    }

    @Test func cancelAllStopsWhatHasNotStarted() async {
        let pipeline = ImportPipeline()
        let run = Task { await onDedicatedThread { pipeline.run(files: ["a", "b", "c", "d"]) } }
        await suspend(ms: 40)
        pipeline.cancelAll()
        _ = await run.value
        let log = pipeline.log.all
        #expect(log.count < 12, "cancelAll didn't stop anything: \(log)")
        for entry in log where !entry.hasPrefix("download") {
            let file = entry.split(separator: " ")[1]
            let needed = entry.hasPrefix("parse") ? "download \(file)" : "parse \(file)"
            #expect(log.contains(needed), "'\(entry)' ran without '\(needed)'")
        }
    }
}

// MARK: - P7.02

@Suite struct P7_02Tests {
    @Test func puzzle1() async { #expect(P7_02.puzzle1 == (await MarathonPuzzles.puzzle1())) }
    @Test func puzzle2() async { #expect(P7_02.puzzle2 == (await MarathonPuzzles.puzzle2())) }
    @Test func puzzle3() async { #expect(P7_02.puzzle3 == (await MarathonPuzzles.puzzle3())) }
    @Test func puzzle4() async { #expect(P7_02.puzzle4 == (await MarathonPuzzles.puzzle4())) }
    @Test func puzzle5() async { #expect(P7_02.puzzle5 == (await MarathonPuzzles.puzzle5())) }
    @Test func puzzle6() async { #expect(P7_02.puzzle6 == (await MarathonPuzzles.puzzle6())) }
    @Test func puzzle7() async { #expect(P7_02.puzzle7 == (await MarathonPuzzles.puzzle7())) }
    @Test func puzzle8() async { #expect(P7_02.puzzle8 == (await MarathonPuzzles.puzzle8())) }
    @Test func puzzle9() async { #expect(P7_02.puzzle9 == (await MarathonPuzzles.puzzle9())) }
    @Test func puzzle10() async { #expect(P7_02.puzzle10 == (await MarathonPuzzles.puzzle10())) }
}

// MARK: - P7.03

private struct FetchBroke: Error {}

private func outcome(_ r: Result<String, any Error>?) -> String {
    switch r {
    case .success(let v): v
    case .failure(let e) where e is DeadlineExceeded: "deadline"
    case .failure(let e) where e is FetchBroke: "broke"
    case .failure(let e): "other: \(e)"
    case nil: "missing"
    }
}

@Suite struct P7_03Tests {
    @Test func allSucceedWithinTheLimit() async throws {
        let meter = ConcurrencyMeter()
        let results = try await withLabTimeout(seconds: 3) {
            await P7_03.fetchAll(Array(1...10), maxConcurrent: 3, deadline: .seconds(1)) { id in
                meter.enter()
                defer { meter.leave() }
                try await Task.sleep(for: .milliseconds(10))
                return "v\(id)"
            }
        }
        #expect(results.count == 10)
        for id in 1...10 { #expect(outcome(results[id]) == "v\(id)") }
        #expect(meter.peak == 3, "peak in flight: \(meter.peak)")
    }

    @Test func deadlineCancelsWhatIsStillRunning() async throws {
        let cancellations = CallCounter()
        var results: [Int: Result<String, any Error>] = [:]
        let elapsed = try await measureMs {
            results = try await withLabTimeout(seconds: 3) {
                await P7_03.fetchAll(Array(1...6), maxConcurrent: 6, deadline: .milliseconds(100)) { id in
                    do { try await Task.sleep(for: .milliseconds(id * 30)) } catch { cancellations.increment(); throw error }
                    return "v\(id)"
                }
            }
        }
        #expect((1...3).map { outcome(results[$0]) } == ["v1", "v2", "v3"])
        #expect((4...6).map { outcome(results[$0]) } == ["deadline", "deadline", "deadline"])
        #expect(cancellations.count == 3, "fetches still running at the deadline must be cancelled")
        #expect(elapsed < 250, "returned \(elapsed)ms after a 100ms deadline")
    }

    @Test func notStartedByTheDeadlineCountsAsDeadline() async throws {
        let results = try await withLabTimeout(seconds: 3) {
            await P7_03.fetchAll([1, 2, 3, 4], maxConcurrent: 1, deadline: .milliseconds(100)) { id in
                try await Task.sleep(for: .milliseconds(80))
                return "v\(id)"
            }
        }
        #expect([1, 2, 3, 4].map { outcome(results[$0]) } == ["v1", "deadline", "deadline", "deadline"])
    }

    @Test func fetchErrorsAreReportedPerID() async throws {
        let results = try await withLabTimeout(seconds: 3) {
            await P7_03.fetchAll([1, 2, 3], maxConcurrent: 3, deadline: .seconds(1)) { id in
                if id == 2 { throw FetchBroke() }
                return "v\(id)"
            }
        }
        #expect([1, 2, 3].map { outcome(results[$0]) } == ["v1", "broke", "v3"])
    }
}

// MARK: - P7.04

@Suite struct P7_04Tests {
    @Test func concurrentButInOrderAndEarly() async throws {
        let meter = ConcurrencyMeter()
        let emitted = Locked<[(value: Int, ms: Int)]>([])
        let start = ContinuousClock.now
        @Sendable func elapsed() -> Int { Int((ContinuousClock.now - start) / .milliseconds(1)) }
        try await withLabTimeout(seconds: 5) {
            await P7_04.mapOrdered(Array(0..<20), maxConcurrent: 4, transform: { x in
                meter.enter()
                defer { meter.leave() }
                try? await Task.sleep(for: .milliseconds(((19 - x) % 7 + 1) * 6))
                return x * 10
            }, emit: { value in
                let t = elapsed()
                emitted.withLock { $0.append((value, t)) }
            })
        }
        let total = elapsed()
        let values = emitted.value.map(\.value)
        #expect(values == (0..<20).map { $0 * 10 }, "emitted \(values)")
        #expect(meter.peak <= 4 && meter.peak > 1, "peak in flight: \(meter.peak)")
        let firstEmit = emitted.value.first?.ms ?? total
        #expect(Double(firstEmit) < Double(total) * 0.5, "first result emitted at \(firstEmit)ms of \(total)ms — wait-for-everything isn't 'as soon as possible'")
    }

    @Test func emptyInput() async throws {
        let count = CallCounter()
        try await withLabTimeout(seconds: 1) {
            await P7_04.mapOrdered([], maxConcurrent: 3, transform: { $0 }, emit: { _ in count.increment() })
        }
        #expect(count.count == 0)
    }
}

// MARK: - P7.05

@Suite struct P7_05Tests {
    @Test func yieldsCurrentThenUpdates() async throws {
        let value = AsyncValue(0)
        let consumer = Task {
            var seen: [Int] = []
            for await v in value.values() {
                seen.append(v)
                if v == 2 { break }
            }
            return seen
        }
        await settle()
        value.send(1)
        await suspend(ms: 10)
        value.send(2)
        let seen = try await withLabTimeout(seconds: 1) { await consumer.value }
        #expect(seen == [0, 1, 2])
        #expect(value.value == 2)
    }

    @Test func lateSubscriberStartsFromTheLatestValue() async throws {
        let value = AsyncValue("a")
        value.send("b")
        value.send("c")
        let first = try await withLabTimeout(seconds: 1) {
            var it = value.values().makeAsyncIterator()
            return await it.next()
        }
        #expect(first == "c")
    }

    @Test func slowSubscriberGetsTheLatestNotABacklog() async throws {
        let value = AsyncValue(0)
        let consumer = Task {
            var seen: [Int] = []
            for await v in value.values() {
                seen.append(v)
                try? await Task.sleep(for: .milliseconds(15))
            }
            return seen
        }
        await settle()
        for i in 1...50 { value.send(i) }
        await suspend(ms: 60)
        value.finish()
        let seen = try await withLabTimeout(seconds: 2) { await consumer.value }
        #expect(seen.last == 50, "the latest value must be delivered: \(seen)")
        #expect(seen.count < 10, "a slow subscriber should skip intermediate states, got \(seen.count) values")
    }

    @Test func finishEndsEverySubscriberAndLeaversAreRemoved() async throws {
        let value = AsyncValue(0)
        let stays = Task { for await _ in value.values() {} }
        let leaves = Task { for await _ in value.values() { break } }
        try await withLabTimeout(seconds: 1) { await leaves.value }
        await settle()
        #expect(value.subscriberCount == 1, "the subscriber that left is still registered")
        value.finish()
        try await withLabTimeout(seconds: 1) { await stays.value }
        #expect(value.subscriberCount == 0)
    }
}
