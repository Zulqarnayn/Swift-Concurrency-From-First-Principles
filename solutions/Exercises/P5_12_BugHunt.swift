import LabKit

// P5.12 — SOLUTION. Timed bug hunt (25 minutes). Four bugs. No hints in the code.
// Lesson: lessons/P5-bug-zoo/12-timed-bug-hunt.md
// Test:   swift test --filter P5_12

/// Fake backend (don't edit).
public final class StoreBackend: Sendable {
    public let productFetches = CallCounter()
    public let charges = EventLog()
    private let stock = Locked<[String: Int]>(["mug": 1, "tee": 5])

    public init() {}

    public func product(_ id: String) async throws -> String {
        productFetches.increment()
        try await Task.sleep(for: .milliseconds(30))
        return "Product(\(id))"
    }

    public func stockLevel(_ id: String) async -> Int {
        await suspend(ms: 10)
        return stock.value[id, default: 0]
    }

    public func reserve(_ id: String) async {
        await suspend(ms: 5)
        stock.withLock { $0[id, default: 0] -= 1 }
    }

    public func remaining(_ id: String) -> Int { stock.value[id, default: 0] }

    public func charge(_ order: Int) async throws {
        try await Task.sleep(for: .milliseconds(Int.random(in: 1...20)))
        charges.add("\(order)")
    }
}

public actor ProductCache {
    private let backend: StoreBackend
    private var cache: [String: String] = [:]
    private var inFlight: [String: Task<String, any Error>] = [:]

    public init(backend: StoreBackend) { self.backend = backend }

    // BUG A — reentrancy: concurrent misses each started a fetch. FIX: single-flight (P2.04).
    public func product(_ id: String) async throws -> String {
        if let hit = cache[id] { return hit }
        if let running = inFlight[id] { return try await running.value }
        let backend = self.backend
        let task = Task { try await backend.product(id) }
        inFlight[id] = task
        defer { inFlight[id] = nil }
        let product = try await task.value
        cache[id] = product
        return product
    }
}

public actor Checkout {
    private let backend: StoreBackend
    private var tail: Task<Bool, Never>?
    public init(backend: StoreBackend) { self.backend = backend }

    // BUG B — check-then-act across an await (P0.04 / P2.04): every buyer saw "1 in stock" before anyone
    // reserved it. The backend's check and reserve are separate async calls, so the actor can't make them
    // atomic by itself. FIX: run purchases one at a time — chain each one after the previous (an async
    // serial queue). (Better still: an atomic `reserveIfAvailable` on the backend, if you own it.)
    public func buy(_ id: String) async -> Bool {
        let previous = tail
        let backend = self.backend
        let task = Task {
            _ = await previous?.value
            guard await backend.stockLevel(id) > 0 else { return false }
            await backend.reserve(id)
            return true
        }
        tail = task
        return await task.value
    }
}

public final class PaymentQueue: Sendable {
    private let inbox: AsyncStream<Int>.Continuation

    // BUG C — one Task per order: they run concurrently, so charges land in random order (P1.08).
    // FIX: one consumer task draining an AsyncStream = an async serial queue.
    public init(backend: StoreBackend) {
        let (stream, continuation) = AsyncStream.makeStream(of: Int.self)
        inbox = continuation
        Task {
            for await order in stream { try? await backend.charge(order) }
        }
    }

    public func enqueue(_ order: Int) {
        inbox.yield(order)
    }

    deinit { inbox.finish() }
}

public enum PriceRefresher {
    /// Polls prices every 20ms until cancelled. Returns the number of polls made.
    // BUG D — `try?` swallowed cancellation: once cancelled, every sleep returned instantly and the loop
    // hammered `fetch` with no delay (P4.11). FIX: let the sleep's CancellationError end the loop.
    public static func poll(_ fetch: @Sendable () async -> Void) async -> Int {
        var polls = 0
        while !Task.isCancelled {
            await fetch()
            polls += 1
            do { try await Task.sleep(for: .milliseconds(20)) } catch { break }
            if polls >= 1_000 { break }
        }
        return polls
    }
}
