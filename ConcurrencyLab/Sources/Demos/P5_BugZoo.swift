import Exercises
import Foundation
import LabKit
@preconcurrency import UnsafeZone

// Phase 5 demos are REPRO HARNESSES: they run YOUR current code in Sources/Exercises.
// Run one before you fix the bug (see the symptom), and again after (see it gone).

let phase5: [Demo] = [
    Demo("p5.01", "Repro: cart total after quick taps (runs YOUR CartModel)", p5_01),
    Demo("p5.03", "Repro: fast scrolling + pull-to-refresh (runs YOUR FeedModel)", p5_03),
    Demo("p5.04", "Repro: location requests (runs YOUR P5_04.currentLocation)", p5_04),
    Demo("p5.05", "Repro: 16 photo syncs at once (runs YOUR PhotoSyncService)", p5_05),
    Demo("p5.06", "Repro: open and close the chat 5 times (runs YOUR ChatViewModel)", p5_06),
    Demo("p5.07", "Repro: leave the screen mid-upload (runs YOUR UploadController)", p5_07),
    Demo("p5.08", "Repro: tap Export while the UI animates (runs YOUR ExportModel)", p5_08),
    Demo("p5.09", "Repro: two screens subscribe to live scores (runs YOUR EventHub)", p5_09),
    Demo("p5.10", "Crash forensics: the list of crash demos to examine", p5_10),
]

// MARK: - P5.01

@MainActor
func p5_01() async {
    var wrong = 0
    var example = ""
    for _ in 0..<20 {
        let cart = CartModel(prices: LivePriceService())
        await withTaskGroup(of: Void.self) { group in
            for sku in ["a", "bb", "ccc"] { group.addTask { await cart.add(sku) } }
        }
        if cart.total != 600 {
            wrong += 1
            example = "items \(cart.items) → total \(cart.total) (expected 600)"
        }
    }
    trace("3 quick taps, 20 trials: wrong total in \(wrong)/20 runs \(wrong > 0 ? "— e.g. \(example)" : "✅")")
}

// MARK: - P5.03

@MainActor
func p5_03() async {
    let server = FeedServer()
    let feed = FeedModel(server: server)
    async let a: Void = feed.loadNextPage()
    async let b: Void = feed.loadNextPage()
    async let c: Void = feed.loadNextPage()
    _ = await (a, b, c)
    trace("3 'near the bottom' events at once → requested pages \(server.requests.all), posts \(feed.posts)")

    let slowServer = FeedServer(latency: { $0 == 2 ? 80 : 10 })
    let feed2 = FeedModel(server: slowServer)
    await feed2.loadNextPage()
    let scroll = Task { await feed2.loadNextPage() }
    await suspend(ms: 20)
    await feed2.refresh()
    await scroll.value
    await suspend(ms: 100)
    trace("scroll (slow page 2) + pull-to-refresh → posts \(feed2.posts)")
}

// MARK: - P5.04

func p5_04() async {
    for scenario in [LegacyLocationProvider.Scenario.success, .denied] {
        let provider = LegacyLocationProvider(scenario: scenario)
        do {
            let location = try await withLabTimeout(seconds: 1) { try await P5_04.currentLocation(from: provider) }
            trace("\(scenario): location \(location)")
        } catch {
            trace("\(scenario): \(error)")
        }
    }
    let provider = LegacyLocationProvider(scenario: .slow)
    let task = Task { try await P5_04.currentLocation(from: provider) }
    await suspend(ms: 20)
    task.cancel()
    do {
        let result = try await withLabTimeout(seconds: 1) { await task.result }
        trace("slow + cancelled: \(result), provider stopped \(provider.stopCount) time(s)")
    } catch {
        trace("slow + cancelled: \(error), provider stopped \(provider.stopCount) time(s)")
    }
}

// MARK: - P5.05

@concurrent
func p5_05() async {
    let service = PhotoSyncService()
    let elapsed = await measureMs {
        await withTaskGroup(of: Int.self) { group in
            for i in 0..<16 { group.addTask { await service.sync([i * 2, i * 2 + 1]) } }
            for await _ in group {}
        }
    }
    trace("16 concurrent syncs of 2 photos: \(service.uploaded.count)/32 uploaded in \(elapsed)ms")
}

// MARK: - P5.06

@MainActor
func p5_06() async {
    let backend = ChatBackend()
    var models: [WeakBox] = []
    for _ in 0..<5 {
        let model = ChatViewModel(backend: backend)
        model.start()
        models.append(WeakBox(model))
        await suspend(ms: 20) // user reads for a bit, then leaves (we drop our reference)
    }
    await suspend(ms: 60)
    let alive = models.filter { $0.value != nil }.count
    let polls = backend.polls.count
    await suspend(ms: 50)
    trace("opened and closed the chat 5 times: \(alive) view models still alive, \(backend.activeSubscriptions) message streams running, \(backend.polls.count - polls) polls in the last 50ms")
}

@MainActor
final class WeakBox {
    weak var value: ChatViewModel?
    init(_ value: ChatViewModel) { self.value = value }
}

// MARK: - P5.07

@MainActor
func p5_07() async {
    let uploader = LegacyUploader(failFirst: 1)
    let controller = UploadController(uploader: uploader)
    let task = Task { await controller.upload("vacation.mov") }
    await suspend(ms: 120)
    trace("user leaves the screen during the retry backoff → cancel()")
    task.cancel()
    let elapsed = await measureMs { await task.value }
    trace("upload task ended \(elapsed)ms later; attempts \(uploader.attempts); uploaded \(controller.uploadedFiles); alerts \(controller.alerts)")
}

// MARK: - P5.08

@MainActor
func p5_08() async {
    let model = ExportModel()
    let worstGap = Locked(0)
    let heartbeat = Task { @MainActor in
        var last = ContinuousClock.now
        while !Task.isCancelled {
            try? await Task.sleep(for: .milliseconds(2))
            let now = ContinuousClock.now
            worstGap.withLock { $0 = max($0, Int((now - last) / .milliseconds(1))) }
            last = now
        }
    }
    await suspend(ms: 10)
    _ = await model.export((0..<3).map { Note(title: "n\($0)", body: "") })
    await suspend(ms: 20) // let the heartbeat run and RECORD the stall before we read it
    heartbeat.cancel()
    trace("export: '\(model.status)' — the main thread's longest freeze was \(worstGap.value)ms (a 60Hz frame is 16ms)")
}

// MARK: - P5.09

func p5_09() async {
    let hub = EventHub()
    let screen1 = hub.subscribe()
    let screen2 = hub.subscribe()
    let c1 = Task { var r: [Int] = []; for await e in screen1 { r.append(e) }; return r }
    let c2 = Task { var r: [Int] = []; for await e in screen2 { r.append(e) }; return r }
    for score in 1...8 { hub.publish(score) }
    await suspend(ms: 30)
    hub.shutdown()
    let r1 = (try? await withLabTimeout(seconds: 1) { await c1.value }).map { "\($0)" } ?? "still waiting after shutdown()"
    let r2 = (try? await withLabTimeout(seconds: 1) { await c2.value }).map { "\($0)" } ?? "still waiting after shutdown()"
    trace("screen 1 saw \(r1)")
    trace("screen 2 saw \(r2)")
}

// MARK: - P5.10

func p5_10() async {
    for id in ["p0.02b", "p0.05b", "p0.05c", "p1.03c", "p1.05c", "p2.05c", "p2.12c", "p2.13c", "p4.04c"] {
        trace("swift run lab \(id)")
    }
    trace("Run each. Note HOW it dies (signal, message, watchdog) before reading its source.")
}
