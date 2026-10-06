import Dispatch
import Exercises
import Foundation
import LabKit
import Puzzles
import Testing

@Suite struct P1_01Tests {
    @Test func returnsSquare() async throws {
        #expect(try await P1_01.slowSquare(7) == 49)
    }

    @Test func manyConcurrentCallsDontStarveThePool() async throws {
        let n = ProcessInfo.processInfo.activeProcessorCount * 4
        let elapsed = try await measureMs {
            try await withThrowingTaskGroup(of: Int.self) { group in
                for i in 0..<n { group.addTask { try await P1_01.slowSquare(i) } }
                for try await _ in group {}
            }
        }
        // Suspending: ≈100ms no matter how many. Blocking: ≈ (n / pool width) × 100ms ≥ 400ms.
        #expect(elapsed < 250, "\(n) concurrent calls took \(elapsed)ms — is a thread being blocked?")
    }

    @Test func respectsCancellation() async {
        let task = Task { try await P1_01.slowSquare(3) }
        task.cancel()
        let result = await task.result
        #expect(throws: CancellationError.self) { try result.get() }
    }
}

@Suite struct P1_02Tests {
    func runCPS(_ cartID: String) async -> (calls: Int, result: Result<Receipt, ShopError>?) {
        await onDedicatedThread { Self.runCPSBlocking(cartID) }!
    }

    static func runCPSBlocking(_ cartID: String) -> (calls: Int, result: Result<Receipt, ShopError>?) {
        let calls = CallCounter()
        let first = Locked<Result<Receipt, ShopError>?>(nil)
        let firstCall = DispatchSemaphore(value: 0)
        P1_02.checkoutCPS(cartID: cartID) { result in
            calls.increment()
            first.withLock { if $0 == nil { $0 = result } }
            firstCall.signal()
        }
        _ = firstCall.wait(timeout: .now() + 1)
        usleep(50_000)
        return (calls.count, first.value)
    }

    @Test func success() async {
        let r = await runCPS("c1")
        #expect(r.calls == 1)
        #expect(r.result == .success(Receipt(paymentID: "pay-60", total: 60)))
    }

    @Test func cartNotFound() async {
        let r = await runCPS("nope")
        #expect(r.calls == 1)
        #expect(r.result == .failure(.cartNotFound))
    }

    @Test func declined() async {
        let r = await runCPS("big")
        #expect(r.calls == 1)
        #expect(r.result == .failure(.cardDeclined))
    }

    @Test func matchesAsyncVersion() async throws {
        let asyncReceipt = try await P1_02.checkout(cartID: "c1")
        #expect(await runCPS("c1").result == .success(asyncReceipt))
    }
}

@Suite struct P1_03Tests {
    @Test func manyConcurrentCallersStillGetCorrectTotals() async throws {
        let callers = ProcessInfo.processInfo.activeProcessorCount * 2
        let totals = try await withLabTimeout(seconds: 10) {
            await withTaskGroup(of: Int.self) { group in
                for _ in 0..<callers {
                    group.addTask { await P1_03.total(for: ["a", "bb", "ccc"]) }
                }
                var all: [Int] = []
                for await t in group { all.append(t) }
                return all
            }
        }
        #expect(totals == Array(repeating: 60, count: callers), "some callers timed out waiting on a parked pool")
    }

    @Test func isFastWhenNotBlocking() async {
        let elapsed = await measureMs { _ = await P1_03.total(for: ["a", "bb", "ccc"]) }
        #expect(elapsed < 500)
    }
}

@Suite struct P1_04Tests {
    @Test func saveCompletesBeforeReturning() async {
        let store = NotesStore(disk: FakeDisk())
        await store.save("buy milk")
        #expect(store.disk.all == ["buy milk"], "`await save` returned but the note isn't on disk")
    }

    @Test func startSavingReturnsAHandle() async {
        let store = NotesStore(disk: FakeDisk())
        let handle = store.startSaving("first")
        #expect(store.disk.all.isEmpty, "startSaving must not wait for the write")
        let count = await handle.value
        #expect(count == 1)
        #expect(store.disk.all == ["first"])
    }
}

@Suite struct P1_05Tests {
    @Test func knownCity() async throws {
        let t = try await withLabTimeout(seconds: 2) { try await P1_05.temperature(in: "Paris") }
        #expect(t == 21)
        let o = try await withLabTimeout(seconds: 2) { try await P1_05.temperature(in: "Oslo") }
        #expect(o == -3)
    }

    @Test func unknownCityThrows() async {
        await #expect(throws: WeatherError.unknownCity) {
            try await withLabTimeout(seconds: 2) { try await P1_05.temperature(in: "Atlantis") }
        }
    }

    @Test func fullImageOnly() async throws {
        let image = try await withLabTimeout(seconds: 2) { await P1_05.fullImage(id: "cat") }
        #expect(image == FakeImage(id: "cat", isDegraded: false))
    }
}

@Suite struct P1_06Tests {
    @Test func streamsReadingsInOrder() async throws {
        let monitor = LegacyHeartRateMonitor()
        let readings = try await withLabTimeout(seconds: 2) {
            var got: [Int] = []
            for await bpm in P1_06.heartRates(from: monitor) {
                got.append(bpm)
                if got.count == 3 { break }
            }
            return got
        }
        #expect(readings == [60, 61, 62])
    }

    @Test func stopsMonitorWhenConsumerStops() async throws {
        let monitor = LegacyHeartRateMonitor()
        try await withLabTimeout(seconds: 2) {
            for await _ in P1_06.heartRates(from: monitor) { break }
        }
        await suspend(ms: 30)
        #expect(monitor.isRunning == false, "monitor still running after the consumer left: a leak")
    }

    @Test func average() async {
        let (s, c) = AsyncStream.makeStream(of: Int.self)
        for v in [1, 2, 3, 4] { c.yield(v) }
        c.finish()
        #expect(await P1_06.average(of: s) == 2.5)

        let (empty, ec) = AsyncStream.makeStream(of: Int.self)
        ec.finish()
        #expect(await P1_06.average(of: empty) == 0)
    }
}

@Suite struct P1_07Tests {
    @Test func happyPath() async throws {
        #expect(try await P1_07.loadProfile(id: 1) == UserProfile(name: "Ada", avatar: "avatar-1.png"))
    }

    @Test func avatarFailureFallsBack() async throws {
        #expect(try await P1_07.loadProfile(id: 2) == UserProfile(name: "Linus", avatar: "default.png"))
    }

    @Test func mapsNameErrors() async {
        await #expect(throws: ProfileLoadError.offline) { try await P1_07.loadProfile(id: 0) }
        await #expect(throws: ProfileLoadError.userNotFound) { try await P1_07.loadProfile(id: 404) }
        await #expect(throws: ProfileLoadError.unknown) { try await P1_07.loadProfile(id: 408) }
    }
}

@Suite struct P1_08Tests {
    @Test func uploadsInOrder() async {
        let server = FakeServer()
        let syncer = MessageSyncer(server: server)
        for message in 1...20 { syncer.didReceive(message) }

        let deadline = ContinuousClock.now + .seconds(3)
        while server.received.count < 20 && ContinuousClock.now < deadline {
            await suspend(ms: 10)
        }
        #expect(server.received == Array(1...20))
        withExtendedLifetime(syncer) {}
    }

    @Test func didReceiveDoesNotBlock() {
        let syncer = MessageSyncer(server: FakeServer())
        let elapsed = measureSyncMs { for m in 1...20 { syncer.didReceive(m) } }
        #expect(elapsed < 20)
    }
}

@Suite struct P1_09Tests {
    static let expected = Feed(
        user: FeedUser(id: 7, name: "Ada"),
        posts: [Post(id: 1, title: "Hello"), Post(id: 2, title: "Async"), Post(id: 3, title: "Await")],
        thumbnails: [1: "https://img.example/1.png", 2: "https://img.example/2.png", 3: "https://img.example/3.png"]
    )

    @Test func loadsFeed() async throws {
        let feed = try await withLabTimeout(seconds: 2) { try await ModernFeedService.loadFeed(token: "abc") }
        #expect(feed == Self.expected)
    }

    @Test func notLoggedIn() async {
        await #expect(throws: FeedError.notLoggedIn) { try await ModernFeedService.loadFeed(token: "") }
    }

    @Test func serverError() async {
        await #expect(throws: FeedError.server) { try await ModernFeedService.loadFeed(token: "server-down") }
    }

    @Test func matchesLegacy() async throws {
        let legacy: Feed = try await withCheckedThrowingContinuation { c in
            LegacyFeedService.loadFeed(token: "abc", callbackQueue: .global()) { c.resume(with: $0) }
        }
        #expect(try await ModernFeedService.loadFeed(token: "abc") == legacy)
    }
}

@Suite struct P1_10Tests {
    @Test func puzzle1() async { #expect(P1_10.puzzle1 == (await AsyncPuzzles.puzzle1())) }
    @Test func puzzle2() async { #expect(P1_10.puzzle2 == (await AsyncPuzzles.puzzle2())) }
    @Test func puzzle3() async { #expect(P1_10.puzzle3 == (await AsyncPuzzles.puzzle3())) }
    @Test func puzzle4() async { #expect(P1_10.puzzle4 == (await AsyncPuzzles.puzzle4())) }
    @Test func puzzle5() async { #expect(P1_10.puzzle5 == (await AsyncPuzzles.puzzle5())) }
    @Test func puzzle6() async { #expect(P1_10.puzzle6 == (await AsyncPuzzles.puzzle6())) }
    @Test func puzzle7() async { #expect(P1_10.puzzle7 == (await AsyncPuzzles.puzzle7())) }
    @Test func puzzle8() async { #expect(P1_10.puzzle8 == (await AsyncPuzzles.puzzle8())) }
}
