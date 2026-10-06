import Exercises
import Foundation
import LabKit
import Puzzles
import Testing

@Suite struct P3_01Tests {
    @Test func childrenFinishBeforeLoadReturns() async {
        let loader = DashboardLoader()
        await loader.load()
        #expect(Set(loader.log.all) == ["profile done", "feed done"], "work outlived load(): \(loader.log.all)")
    }

    @Test func cancellingTheCallerCancelsTheChildren() async {
        let loader = DashboardLoader()
        let caller = Task { await loader.load() }
        await suspend(ms: 20)
        caller.cancel()
        await caller.value
        await suspend(ms: 120) // give unstructured children (if any) time to finish anyway
        #expect(Set(loader.log.all) == ["profile cancelled", "feed cancelled"], "\(loader.log.all)")
    }
}

@Suite struct P3_02Tests {
    @Test func fetchesConcurrently() async throws {
        let api = DashboardAPI()
        var dashboard: Dashboard?
        let elapsed = try await measureMs { dashboard = try await P3_02.loadDashboard(api: api) }
        #expect(dashboard == Dashboard(user: "Ada", news: ["Swift 6.2 ships"], weather: "Sunny"))
        #expect(elapsed < 200, "took \(elapsed)ms — sequential is ~300ms")
    }

    @Test func failureCancelsTheRest() async {
        let api = DashboardAPI(newsFails: true)
        let elapsed = await measureMs {
            await #expect(throws: NewsUnavailable.self) { try await P3_02.loadDashboard(api: api) }
        }
        #expect(api.log.all.contains("weather cancelled"), "weather should have STARTED concurrently and then been cancelled: \(api.log.all)")
        #expect(elapsed < 300, "took \(elapsed)ms — the 400ms weather call should have been cancelled")
    }
}

@Suite struct P3_03Tests {
    @Test func fetchesAllConcurrently() async {
        let api = ThumbnailAPI()
        var result: [Int: String] = [:]
        let elapsed = await measureMs { result = await P3_03.thumbnails(for: [1, 2, 3, -4, 5, 6, 7, 8], api: api) }
        #expect(result.count == 7)
        #expect(result[5] == "thumb-5.png")
        #expect(result[-4] == nil)
        #expect(api.meter.peak > 1)
        #expect(elapsed < 300, "took \(elapsed)ms — sequential is ~700ms")
    }

    @Test func requireAllFailsFastAndCancelsTheRest() async {
        let api = ThumbnailAPI()
        let elapsed = await measureMs {
            await #expect(throws: ThumbnailMissing(id: -2)) { try await P3_03.requireAll([1, -2, 3, 4, 5], api: api) }
        }
        #expect(elapsed < 60, "took \(elapsed)ms — the error happens at 10ms; did you wait for the others (100ms each)?")
        #expect(api.cancellations.count == 4, "the 4 good fetches still running should be cancelled")
    }

    @Test func requireAllSucceeds() async throws {
        let api = ThumbnailAPI()
        let result = try await P3_03.requireAll([1, 2, 3], api: api)
        #expect(result == [1: "thumb-1.png", 2: "thumb-2.png", 3: "thumb-3.png"])
    }
}

@Suite struct P3_04Tests {
    @Test func boundedAndOrdered() async {
        let downloader = BoundedDownloader()
        let ids = Array(0..<30)
        var files: [String] = []
        let elapsed = await measureMs { files = await P3_04.downloadAll(ids, maxConcurrent: 3, using: downloader) }
        #expect(files == ids.map { "file-\($0)" }, "results must be in input order")
        #expect(downloader.meter.peak == 3, "peak in flight was \(downloader.meter.peak)")
        #expect(elapsed < 400, "took \(elapsed)ms — 30 jobs / 3 wide × 20ms ≈ 200ms")
    }

    @Test func fewerItemsThanTheLimit() async {
        let downloader = BoundedDownloader()
        #expect(await P3_04.downloadAll([7, 8], maxConcurrent: 5, using: downloader) == ["file-7", "file-8"])
        #expect(await P3_04.downloadAll([], maxConcurrent: 5, using: downloader) == [])
    }
}

@Suite struct P3_05Tests {
    @Test func handlesConcurrentlyAndReturnsWhenDone() async {
        let (requests, inbox) = AsyncStream.makeStream(of: Int.self)
        let handled = CallCounter()
        let meter = ConcurrencyMeter()
        for i in 1...10 { inbox.yield(i) }
        inbox.finish()
        let elapsed = await measureMs {
            await P3_05.serve(requests) { _ in
                meter.enter()
                await suspend(ms: 30)
                meter.leave()
                handled.increment()
            }
        }
        #expect(handled.count == 10, "serve() returned before every request was handled")
        #expect(meter.peak > 1)
        #expect(elapsed < 150, "took \(elapsed)ms — one at a time is ~300ms")
    }
}

@Suite struct P3_06Tests {
    @Test func primesStopPromptlyWhenCancelled() async {
        let task = Task { try await P3_06.countPrimes(below: 15_000) }
        await suspend(ms: 10)
        let elapsed = await measureMs {
            task.cancel()
            _ = await task.result
        }
        let result = await task.result
        #expect(throws: CancellationError.self) { try result.get() }
        #expect(elapsed < 100, "kept computing for \(elapsed)ms after cancel()")
    }

    @Test func primesStillCorrect() async throws {
        #expect(try await P3_06.countPrimes(below: 100) == 25)
    }

    @Test func downloadForwardsCancellation() async {
        let legacy = LegacyDownload()
        let task = Task { try await P3_06.download(legacy) }
        await suspend(ms: 20)
        let elapsed = await measureMs {
            task.cancel()
            _ = await task.result
        }
        #expect(legacy.wasCancelled, "the legacy download was never told to cancel")
        let result = await task.result
        #expect(throws: CancellationError.self) { try result.get() }
        #expect(elapsed < 100)
    }

    @Test func downloadCancelledBeforeItStarts() async {
        let legacy = LegacyDownload()
        let task = Task {
            withUnsafeCurrentTask { $0?.cancel() } // cancelled before download() even begins
            return try await P3_06.download(legacy)
        }
        let elapsed = await measureMs { _ = await task.result }
        let result = await task.result
        #expect(throws: CancellationError.self) { try result.get() }
        #expect(elapsed < 100)
    }

    @Test func downloadSucceeds() async throws {
        #expect(try await P3_06.download(LegacyDownload()) == Data("payload".utf8))
    }
}

@Suite struct P3_07Tests {
    @Test @MainActor func onlyTheLatestQueryWins() async {
        let api = SearchAPI()
        let model = SearchModel(api: api)
        model.queryChanged("s")    // 60ms
        model.queryChanged("sw")   // 30ms
        model.queryChanged("swi")  // 10ms
        await suspend(ms: 150)
        #expect(model.results == ["swi1", "swi2"])
        #expect(model.shown == ["swi"], "stale or duplicate results were shown: \(model.shown)")
        #expect(api.cancellations.count == 2, "superseded searches should be cancelled, not ignored")
    }
}

@Suite struct P3_08Tests {
    @Test func fastOperationReturnsItsValue() async throws {
        let value = try await P3_08.withTimeout(.milliseconds(200)) { () async throws -> Int in
            try await Task.sleep(for: .milliseconds(10))
            return 42
        }
        #expect(value == 42)
    }

    @Test func slowOperationTimesOutAndIsCancelled() async {
        let cancelled = CallCounter()
        let elapsed = await measureMs {
            await #expect(throws: TimeoutError()) {
                try await P3_08.withTimeout(.milliseconds(50)) { () async throws -> Int in
                    do { try await Task.sleep(for: .seconds(2)) } catch { cancelled.increment(); throw error }
                    return 1
                }
            }
        }
        #expect(elapsed < 150, "took \(elapsed)ms for a 50ms timeout")
        #expect(cancelled.count == 1, "the timed-out operation must be cancelled, not left running")
    }

    @Test func operationErrorsPropagate() async {
        struct Boom: Error, Equatable {}
        await #expect(throws: Boom()) {
            try await P3_08.withTimeout(.milliseconds(200)) { () async throws -> Int in throw Boom() }
        }
    }

    @Test func callerCancellationIsNotATimeout() async {
        let task = Task {
            try await P3_08.withTimeout(.seconds(5)) { () async throws -> Int in
                try await Task.sleep(for: .seconds(2))
                return 1
            }
        }
        await suspend(ms: 20)
        task.cancel()
        let result = await task.result
        #expect(throws: CancellationError.self) { try result.get() }
    }
}

@Suite struct P3_09Tests {
    @Test @MainActor func otherMainActorWorkGetsToRun() async {
        let ticks = Locked(0)
        let ticker = Task { @MainActor in
            while !Task.isCancelled {
                ticks.withLock { $0 += 1 }
                await Task.yield()
            }
        }
        await Task.yield()
        let before = ticks.value
        let processed = await P3_09.processAll(Array(0..<50))
        let during = ticks.value - before
        ticker.cancel()
        #expect(processed == 50)
        #expect(during >= 10, "another main-actor task ran only \(during) times during 100ms of work")
    }
}

@Suite struct P3_10Tests {
    @Test func everyLineCarriesTheRequestID() async {
        let log = EventLog()
        await P3_10.handle(requestID: "req-7", log: log)
        #expect(log.all.count == 7)
        for line in log.all {
            #expect(line.hasPrefix("[req-7]"), "untagged line: \(line)")
        }
        #expect(log.all.contains("[req-7] audit written"))
        #expect(RequestLog.requestID == nil, "the id must not leak out of handle()")
    }
}

@Suite struct P3_11Tests {
    @Test @MainActor func workStartsBeforeTapReturns() async {
        let model = LikeButtonModel()
        model.tap()
        #expect(model.isLiked, "UI not updated by the time tap() returned")
        #expect(model.events == ["like-started", "tap-returned"])
        let deadline = ContinuousClock.now + .seconds(1)
        while !model.events.contains("like-confirmed") && ContinuousClock.now < deadline {
            await suspend(ms: 5)
        }
        #expect(model.events == ["like-started", "tap-returned", "like-confirmed"])
    }
}

@Suite struct P3_12Tests {
    @Test func puzzle1() async { #expect(P3_12.puzzle1 == (await StructuredPuzzles.puzzle1())) }
    @Test func puzzle2() async { #expect(P3_12.puzzle2 == (await StructuredPuzzles.puzzle2())) }
    @Test func puzzle3() async { #expect(P3_12.puzzle3 == (await StructuredPuzzles.puzzle3())) }
    @Test func puzzle4() async { #expect(P3_12.puzzle4 == (await StructuredPuzzles.puzzle4())) }
    @Test func puzzle5() async { #expect(P3_12.puzzle5 == (await StructuredPuzzles.puzzle5())) }
    @Test func puzzle6() async { #expect(P3_12.puzzle6 == (await StructuredPuzzles.puzzle6())) }
}
