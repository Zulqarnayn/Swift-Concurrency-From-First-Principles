import LabKit

// P5.12 — Timed bug hunt (25 minutes). Four bugs. No hints in the code.
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

    public init(backend: StoreBackend) { self.backend = backend }

    public func product(_ id: String) async throws -> String {
        if let hit = cache[id] { return hit }
        let product = try await backend.product(id)
        cache[id] = product
        return product
    }
}

public actor Checkout {
    private let backend: StoreBackend
    public init(backend: StoreBackend) { self.backend = backend }

    /// Reserve one unit if any is in stock. Returns true on success.
    public func buy(_ id: String) async -> Bool {
        guard await backend.stockLevel(id) > 0 else { return false }
        await backend.reserve(id)
        return true
    }
}

public final class PaymentQueue: Sendable {
    private let backend: StoreBackend
    public init(backend: StoreBackend) { self.backend = backend }

    /// Called synchronously, in order, by the checkout UI. Orders must be charged in that order.
    public func enqueue(_ order: Int) {
        Task { try? await backend.charge(order) }
    }
}

public enum PriceRefresher {
    /// Polls prices every 20ms until cancelled. Returns the number of polls made.
    public static func poll(_ fetch: @Sendable () async -> Void) async -> Int {
        var polls = 0
        while true {
            await fetch()
            polls += 1
            try? await Task.sleep(for: .milliseconds(20))
            if polls >= 1_000 { return polls }
        }
    }
}
