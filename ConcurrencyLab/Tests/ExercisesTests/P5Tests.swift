import Exercises
import Foundation
import LabKit
import Testing
@preconcurrency import UnsafeZone

// MARK: - P5.01

final class ScriptedPrices: PriceService {
    let responder = ScriptedResponder<String, Int>()
    func price(of sku: String) async -> Int { await responder.respond(to: sku) }
}

@Suite struct P5_01Tests {
    /// Deterministic reproduction: force the exact interleaving that loses an update.
    @Test @MainActor func overlappingAddsKeepBothPrices() async throws {
        let prices = ScriptedPrices()
        let cart = CartModel(prices: prices)
        let first = Task { await cart.add("A") }   // costs 100
        let second = Task { await cart.add("BB") } // costs 200
        try await withLabTimeout(seconds: 1) { await prices.responder.waitForPending(2) }
        await prices.responder.resolve("BB", with: 200) // the SECOND request answers first
        await settle()
        await prices.responder.resolve("A", with: 100)
        await first.value
        await second.value
        #expect(cart.items == ["A", "BB"])
        #expect(cart.total == 300, "lost an update: total is \(cart.total)")
    }

    /// The flaky, real-world version of the same bug.
    @Test @MainActor func manyQuickAdds() async {
        let cart = CartModel(prices: LivePriceService())
        let skus = ["a", "bb", "ccc", "dddd", "eeeee", "ffffff"]
        await withTaskGroup(of: Void.self) { group in
            for sku in skus { group.addTask { await cart.add(sku) } }
        }
        #expect(cart.total == 2_100)
    }
}

// MARK: - P5.02

@Suite struct P5_02Tests {
    /// Passes even with the bug. The REAL test is: scripts/stress.sh P5_02 10 --tsan
    @Test func concurrentLoginsLogoutsAndReads() async {
        let store = SessionStore()
        await onDedicatedThread {
            onThreads(8) { t in
                for i in 0..<200 {
                    store.login("u\(t)-\(i % 10)")
                    _ = store.activeCount
                    _ = store.secondsSinceLastActivity
                    if i % 3 == 0 { store.logout("u\(t)-\(i % 10)") }
                }
            }
        }
        // Each thread's own keys end up logged in iff their last operation was a login.
        var loggedIn = Set<Int>()
        for i in 0..<200 {
            loggedIn.insert(i % 10)
            if i % 3 == 0 { loggedIn.remove(i % 10) }
        }
        #expect(store.activeCount == loggedIn.count * 8)
    }
}

// MARK: - P5.03

private func page(_ n: Int) -> [String] { (0..<3).map { "p\(n)-\($0)" } }

@Suite struct P5_03Tests {
    @Test @MainActor func rapidScrollLoadsEachPageOnce() async {
        let server = FeedServer()
        let feed = FeedModel(server: server)
        async let a: Void = feed.loadNextPage()
        async let b: Void = feed.loadNextPage()
        async let c: Void = feed.loadNextPage()
        _ = await (a, b, c)
        await feed.loadNextPage()
        #expect(feed.posts == page(1) + page(2), "\(feed.posts)")
        #expect(server.requests.all == ["1", "2"], "requested pages \(server.requests.all)")
    }

    @Test @MainActor func refreshDiscardsAStalePage() async {
        let server = FeedServer(latency: { $0 == 2 ? 80 : 10 })
        let feed = FeedModel(server: server)
        await feed.loadNextPage()                              // page 1
        let scroll = Task { await feed.loadNextPage() }        // page 2: slow
        await suspend(ms: 20)
        await feed.refresh()                                   // back to page 1, fast
        await scroll.value
        await suspend(ms: 100)
        #expect(feed.posts == page(1), "a page from BEFORE the refresh was appended: \(feed.posts)")
        await feed.loadNextPage()
        #expect(feed.posts == page(1) + page(2))
    }
}

// MARK: - P5.04

@Suite struct P5_04Tests {
    @Test func success() async throws {
        let provider = LegacyLocationProvider(scenario: .success)
        let location = try await withLabTimeout(seconds: 1) { try await P5_04.currentLocation(from: provider) }
        #expect(location == 42)
    }

    @Test func permissionDenied() async {
        let provider = LegacyLocationProvider(scenario: .denied)
        await #expect(throws: LocationError.denied) {
            try await withLabTimeout(seconds: 1) { try await P5_04.currentLocation(from: provider) }
        }
    }

    @Test func cancellationStopsTheProvider() async throws {
        let provider = LegacyLocationProvider(scenario: .slow)
        let task = Task { try await P5_04.currentLocation(from: provider) }
        await suspend(ms: 20)
        task.cancel()
        let result = try await withLabTimeout(seconds: 1) { await task.result }
        #expect(throws: CancellationError.self) { try result.get() }
        #expect(provider.stopCount >= 1, "the provider was never stopped")
    }
}

// MARK: - P5.05

@Suite struct P5_05Tests {
    @Test func manyConcurrentSyncsStayFast() async throws {
        let service = PhotoSyncService()
        var total = 0
        let elapsed = try await measureMs {
            total = try await withLabTimeout(seconds: 20) {
                await withTaskGroup(of: Int.self) { group in
                    for i in 0..<16 { group.addTask { await service.sync([i * 2, i * 2 + 1]) } }
                    var sum = 0
                    for await n in group { sum += n }
                    return sum
                }
            }
        }
        #expect(total == 32, "only \(total) of 32 photos were uploaded")
        #expect(elapsed < 500, "16 concurrent syncs took \(elapsed)ms")
    }
}

// MARK: - P5.06

@Suite struct P5_06Tests {
    @Test @MainActor func closingTheChatReleasesEverything() async {
        let backend = ChatBackend()
        weak var weakModel: ChatViewModel?
        do {
            let model = ChatViewModel(backend: backend)
            model.start()
            weakModel = model
            await suspend(ms: 30)
            #expect(!model.messages.isEmpty, "the chat should receive messages while open")
        }
        await suspend(ms: 60)
        #expect(weakModel == nil, "ChatViewModel was never deallocated")
        #expect(backend.activeSubscriptions == 0, "the message stream is still running")
        let polls = backend.polls.count
        await suspend(ms: 50)
        #expect(backend.polls.count == polls, "still polling after the screen closed")
    }
}

// MARK: - P5.07

@Suite struct P5_07Tests {
    @Test @MainActor func leavingDuringBackoffStopsImmediately() async {
        let uploader = LegacyUploader(failFirst: 1)
        let controller = UploadController(uploader: uploader)
        let task = Task { await controller.upload("a.mov") }
        await suspend(ms: 120) // attempt 1 failed at 100ms; now in the 50ms backoff
        task.cancel()
        let elapsed = await measureMs { await task.value }
        #expect(elapsed < 60, "kept going for \(elapsed)ms after cancel")
        #expect(uploader.attempts == 1, "retried after the user left")
        #expect(controller.alerts.isEmpty, "showed an error alert for a cancellation: \(controller.alerts)")
    }

    @Test @MainActor func leavingDuringUploadCancelsTheRequest() async {
        let uploader = LegacyUploader()
        let controller = UploadController(uploader: uploader)
        let task = Task { await controller.upload("a.mov") }
        await suspend(ms: 20)
        task.cancel()
        let elapsed = await measureMs { await task.value }
        #expect(elapsed < 60, "the upload kept running \(elapsed)ms after cancel")
        #expect(uploader.cancels == 1, "the legacy upload was never cancelled")
        #expect(controller.alerts.isEmpty)
        #expect(controller.uploadedFiles.isEmpty)
    }

    @Test @MainActor func retriesStillWork() async {
        let uploader = LegacyUploader(failFirst: 2)
        let controller = UploadController(uploader: uploader)
        await controller.upload("a.mov")
        #expect(controller.uploadedFiles == ["a.mov"])
        #expect(uploader.attempts == 3)
        #expect(controller.alerts.isEmpty)
    }

    @Test @MainActor func realFailureShowsOneAlert() async {
        let uploader = LegacyUploader(failFirst: 5)
        let controller = UploadController(uploader: uploader)
        await controller.upload("a.mov")
        #expect(uploader.attempts == 3)
        #expect(controller.alerts.count == 1)
    }
}

// MARK: - P5.08

@Suite struct P5_08Tests {
    @Test @MainActor func exportKeepsTheMainThreadResponsive() async {
        let model = ExportModel()
        let worstGap = Locked(0)
        let heartbeat = Task { @MainActor in
            var last = ContinuousClock.now
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(2))
                let now = ContinuousClock.now
                let gap = Int((now - last) / .milliseconds(1))
                worstGap.withLock { $0 = max($0, gap) }
                last = now
            }
        }
        await suspend(ms: 10)
        let notes = [Note(title: "a", body: "1"), Note(title: "b", body: "2"), Note(title: "c", body: "3")]
        let data = await model.export(notes)
        await suspend(ms: 20) // let the heartbeat run and RECORD the stall before we read it
        heartbeat.cancel()
        #expect((try? JSONDecoder().decode([Note].self, from: data)) == notes)
        #expect(model.status == "Exported 3 notes")
        #expect(worstGap.value < 80, "the main thread froze for \(worstGap.value)ms")
    }
}

// MARK: - P5.09

@Suite struct P5_09Tests {
    @Test func everySubscriberGetsEveryEventAndShutdownEndsThem() async throws {
        let hub = EventHub()
        let s1 = hub.subscribe()
        let s2 = hub.subscribe()
        let c1 = Task { var r: [Int] = []; for await e in s1 { r.append(e) }; return r }
        let c2 = Task { var r: [Int] = []; for await e in s2 { r.append(e) }; return r }
        for i in 1...10 { hub.publish(i) }
        hub.shutdown()
        let r1 = try await withLabTimeout(seconds: 1) { await c1.value }
        let r2 = try await withLabTimeout(seconds: 1) { await c2.value }
        #expect(r1 == Array(1...10), "subscriber 1 got \(r1)")
        #expect(r2 == Array(1...10), "subscriber 2 got \(r2)")
    }

    @Test func subscribersThatLeaveAreRemoved() async throws {
        let hub = EventHub()
        // The stream must be owned ONLY by the loop: a `let stream = …` held here would keep it alive
        // after the break, and onTermination would never fire (P1.06). The first version of this test
        // made exactly that mistake.
        let consumer = Task {
            for await event in hub.subscribe() where event == 3 { break }
        }
        await settle()
        for i in 1...5 { hub.publish(i) }
        try await withLabTimeout(seconds: 1) { await consumer.value }
        await settle()
        #expect(hub.subscriberCount == 0, "a screen that stopped listening is still subscribed")
    }

    @Test func subscribingAfterShutdownEndsImmediately() async throws {
        let hub = EventHub()
        hub.shutdown()
        let events = try await withLabTimeout(seconds: 1) {
            var r: [Int] = []
            for await e in hub.subscribe() { r.append(e) }
            return r
        }
        #expect(events.isEmpty)
    }
}

// MARK: - P5.10

@Suite struct P5_10Tests {
    @Test func p0_02b() { #expect(P5_10.p0_02b == .heapCorruptionFromDataRace) }
    @Test func p0_05b() { #expect(P5_10.p0_05b == .dispatchSyncOntoOwnQueue) }
    @Test func p0_05c() { #expect(P5_10.p0_05c == .recursiveLock) }
    @Test func p1_03c() { #expect(P5_10.p1_03c == .cooperativePoolDeadlock) }
    @Test func p1_05c() { #expect(P5_10.p1_05c == .continuationResumedTwice) }
    @Test func p2_05c() { #expect(P5_10.p2_05c == .assumeIsolatedWrong) }
    @Test func p2_12c() { #expect(P5_10.p2_12c == .preconcurrencyConformanceOffActor) }
    @Test func p2_13c() { #expect(P5_10.p2_13c == .dynamicIsolationCheck) }
    @Test func p4_04c() { #expect(P5_10.p4_04c == .cooperativePoolDeadlock) }
}

// MARK: - P5.11

@Suite struct P5_11Tests {
    @Test @MainActor func savesOnlyAfterTheUserPauses() async throws {
        let clock = ManualSleeper()
        let autosave = AutosaveController(sleep: clock.sleep)

        autosave.textChanged("a")
        try await withLabTimeout(seconds: 1) { await clock.waitForSleepers(1) }
        await clock.advance(by: .milliseconds(300))
        #expect(autosave.saves.isEmpty)

        autosave.textChanged("ab") // restarts the 500ms countdown
        try await withLabTimeout(seconds: 1) { await clock.waitForSleepers(1) }
        await clock.advance(by: .milliseconds(499))
        #expect(autosave.saves.isEmpty, "saved before the 500ms pause: \(autosave.saves)")

        await clock.advance(by: .milliseconds(1))
        #expect(autosave.saves == ["ab"], "expected exactly one save of the latest text: \(autosave.saves)")
    }

    @Test @MainActor func flushSavesPendingTextOnce() async throws {
        let clock = ManualSleeper()
        let autosave = AutosaveController(sleep: clock.sleep)
        autosave.textChanged("draft")
        try await withLabTimeout(seconds: 1) { await clock.waitForSleepers(1) }
        autosave.flush()
        #expect(autosave.saves == ["draft"])
        await clock.advance(by: .seconds(1))
        #expect(autosave.saves == ["draft"], "saved twice")
    }
}

// MARK: - P5.12

@Suite struct P5_12Tests {
    @Test func scenarioA() async throws {
        let backend = StoreBackend()
        let cache = ProductCache(backend: backend)
        try await withThrowingTaskGroup(of: String.self) { group in
            for _ in 0..<10 { group.addTask { try await cache.product("mug") } }
            for try await _ in group {}
        }
        #expect(backend.productFetches.count == 1)
    }

    @Test func scenarioB() async {
        let backend = StoreBackend()
        let checkout = Checkout(backend: backend)
        let sold = CallCounter()
        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<10 { group.addTask { if await checkout.buy("mug") { sold.increment() } } }
        }
        #expect(sold.count == 1)
        #expect(backend.remaining("mug") == 0)
    }

    @Test func scenarioC() async {
        let backend = StoreBackend()
        let queue = PaymentQueue(backend: backend)
        for order in 1...20 { queue.enqueue(order) }
        let deadline = ContinuousClock.now + .seconds(3)
        while backend.charges.all.count < 20 && ContinuousClock.now < deadline { await suspend(ms: 10) }
        #expect(backend.charges.all == (1...20).map(String.init))
        withExtendedLifetime(queue) {}
    }

    @Test func scenarioD() async {
        let calls = CallCounter()
        let task = Task { await PriceRefresher.poll { calls.increment() } }
        await suspend(ms: 50)
        task.cancel()
        let elapsed = await measureMs { _ = await task.value }
        let afterCancel = calls.count
        await suspend(ms: 50)
        #expect(elapsed < 60)
        #expect(calls.count == afterCancel)
        #expect(afterCancel < 10, "\(afterCancel) polls")
    }
}
