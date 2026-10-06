import LabKit

// P5.01 — SOLUTION. Bug hunt: "the cart total is wrong, sometimes"
// Lesson (bug report + method): lessons/P5-bug-zoo/01-debugging-method.md
// Repro:  swift run lab p5.01        Test: swift test --filter P5_01

public protocol PriceService: Sendable {
    func price(of sku: String) async -> Int
}

/// The real service (don't edit): price = 100 × sku length, with realistic, variable latency.
public final class LivePriceService: PriceService {
    public init() {}
    public func price(of sku: String) async -> Int {
        await suspend(ms: Int.random(in: 5...30))
        return sku.count * 100
    }
}

@MainActor
public final class CartModel {
    public private(set) var items: [String] = []
    public private(set) var total = 0
    private let prices: any PriceService

    public init(prices: any PriceService) {
        self.prices = prices
    }

    /// Called when the user taps "Add to cart" (they can tap several products quickly).
    public func add(_ sku: String) async {
        items.append(sku)
        // ROOT CAUSE: `total` was read BEFORE the suspension point and written after it. Another add()
        // ran on the main actor in between (reentrancy, P2.04) and its update was overwritten (a lost update).
        // FIX: do the read-modify-write in one synchronous step AFTER the await.
        let price = await prices.price(of: sku)
        total += price
    }
}
