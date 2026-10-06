import Exercises
import Foundation
import LabKit
import Puzzles
import Testing

@Suite struct P2_02Tests {
    @Test func a() async { #expect(P2_02.a == (await IsolationMap.a())) }
    @Test func b() async { #expect(P2_02.b == (await IsolationMap.b())) }
    @Test func c() async { #expect(P2_02.c == (await IsolationMap.c())) }
    @Test func d() async { #expect(P2_02.d == (await IsolationMap.d())) }
    @Test func e() async { #expect(P2_02.e == (await IsolationMap.e())) }
    @Test func f() async { #expect(P2_02.f == (await IsolationMap.f())) }
    @Test func g() async { #expect(P2_02.g == (await IsolationMap.g())) }
    @Test func h() async { #expect(P2_02.h == (await IsolationMap.h())) }
    @Test func i() async { #expect(P2_02.i == (await IsolationMap.i())) }
}

@Suite struct P2_03Tests {
    @Test func concurrentDepositsAndWithdrawalsAreExact() async {
        let account = AccountActor(balance: 0)
        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<2_000 { group.addTask { await account.deposit(1) } }
        }
        #expect(await account.balance == 2_000)

        let approved = CallCounter()
        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<3_000 {
                group.addTask { if await account.withdraw(1) { approved.increment() } }
            }
        }
        #expect(approved.count == 2_000)
        #expect(await account.balance == 0)
    }

    @Test func transferConservesMoneyAndNeverOverdraws() async {
        let a = AccountActor(balance: 500)
        let b = AccountActor(balance: 500)
        await withTaskGroup(of: Void.self) { group in
            for i in 0..<1_000 {
                group.addTask {
                    if i.isMultiple(of: 2) { _ = await a.transfer(3, to: b) } else { _ = await b.transfer(3, to: a) }
                }
            }
        }
        let (ba, bb) = (await a.balance, await b.balance)
        #expect(ba + bb == 1_000, "money created or destroyed")
        #expect(ba >= 0 && bb >= 0)
    }

    @Test func transferRefusesWhenBroke() async {
        let a = AccountActor(balance: 10)
        let b = AccountActor(balance: 0)
        #expect(await a.transfer(11, to: b) == false)
        #expect(await a.transfer(10, to: b) == true)
        #expect(await a.balance == 0)
        #expect(await b.balance == 10)
    }
}

@Suite struct P2_04Tests {
    @Test func concurrentRequestsShareOneDownload() async throws {
        let downloader = FakeDownloader()
        let cache = ImageCache(downloader: downloader)
        let results = try await withThrowingTaskGroup(of: Data.self) { group in
            for _ in 0..<10 { group.addTask { try await cache.image(for: "cat.png") } }
            var all: [Data] = []
            for try await d in group { all.append(d) }
            return all
        }
        #expect(results.count == 10)
        #expect(Set(results) == [Data("cat.png".utf8)])
        #expect(downloader.downloads == 1, "\(downloader.downloads) downloads for one URL")
    }

    @Test func differentURLsDownloadSeparately() async throws {
        let downloader = FakeDownloader()
        let cache = ImageCache(downloader: downloader)
        async let a = cache.image(for: "a.png")
        async let b = cache.image(for: "b.png")
        _ = try await (a, b)
        _ = try await cache.image(for: "a.png") // cached now
        #expect(downloader.downloads == 2)
    }

    @Test func failuresAreNotCached() async {
        let downloader = FakeDownloader()
        let cache = ImageCache(downloader: downloader)
        await #expect(throws: DownloadError.self) { try await cache.image(for: "bad.png") }
        await #expect(throws: DownloadError.self) { try await cache.image(for: "bad.png") }
        #expect(downloader.downloads == 2, "the second request must retry, not replay the failure forever")
    }
}

@Suite struct P2_05Tests {
    @Test func writesNeverOverlap() async {
        let db = Database()
        await withTaskGroup(of: Void.self) { group in
            for i in 0..<200 { group.addTask { await db.insert("row \(i)") } }
        }
        #expect(await db.count() == 200)
        #expect(await db.peakConcurrentWrites() == 1)
    }
}

@Suite struct P2_08Tests {
    @Test @MainActor func calledFromMain() async {
        let report = await P2_08.process([1, 2, 3])
        #expect(report.validatedOnMain == true, "validate left the caller's actor")
        #expect(report.filteredOnMain == false, "50ms of filtering ran on the main thread")
    }
}

@Suite struct P2_10Tests {
    @Test func reservationsAreAllOrNothingAndNeverOversell() async {
        for _ in 0..<5 {
            let inventory = Inventory(stock: ["A": 3, "B": 3])
            let wins = CallCounter()
            await withTaskGroup(of: Void.self) { group in
                for _ in 0..<20 {
                    group.addTask { if await P2_10.reserveAll(["A", "B"], in: inventory) { wins.increment() } }
                }
            }
            #expect(wins.count == 3)
            #expect(await inventory.available("A") == 0)
            #expect(await inventory.available("B") == 0)
            #expect(await inventory.lowestStock >= 0, "stock went negative: oversold")
        }
    }

    @Test func failsWhenAnyItemMissing() async {
        let inventory = Inventory(stock: ["A": 1, "B": 0])
        #expect(await P2_10.reserveAll(["A", "B"], in: inventory) == false)
        #expect(await inventory.available("A") == 1, "all-or-nothing: A must not be taken")
    }
}

@Suite struct P2_13Tests {
    @Test @MainActor func recordsReadingsInOrderOnMain() async {
        let model = TemperatureModel()
        model.start(count: 5)
        let deadline = ContinuousClock.now + .seconds(2)
        while model.readings.count < 5 && ContinuousClock.now < deadline {
            await suspend(ms: 10)
        }
        #expect(model.readings == [20, 21, 22, 23, 24])
    }
}

@Suite struct P2_14Tests {
    @Test @MainActor func rapidTapsToggleOnce() async {
        let model = ToggleModel()
        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<5 { group.addTask { await model.tap() } }
        }
        #expect(await model.remote.toggleCount == 1)
        #expect(model.isOn == true)
        #expect(await model.remote.state == true)

        await model.tap() // a later, separate tap works normally
        #expect(await model.remote.toggleCount == 2)
        #expect(model.isOn == false)
    }
}

@Suite struct P2_16Tests {
    @Test func puzzle1() async { #expect(P2_16.puzzle1 == (await IsolationPuzzles.puzzle1())) }
    @Test func puzzle2() async { #expect(P2_16.puzzle2 == (await IsolationPuzzles.puzzle2())) }
    @Test func puzzle3() async { #expect(P2_16.puzzle3 == (await IsolationPuzzles.puzzle3())) }
    @Test func puzzle4() async { #expect(P2_16.puzzle4 == (await IsolationPuzzles.puzzle4())) }
    @Test func puzzle5() async { #expect(P2_16.puzzle5 == (await IsolationPuzzles.puzzle5())) }
    @Test func puzzle6() async { #expect(P2_16.puzzle6 == (await IsolationPuzzles.puzzle6())) }
}
