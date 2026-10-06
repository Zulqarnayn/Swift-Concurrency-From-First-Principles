import Dispatch
import LabKit

// P1.03 — The cooperative thread pool: never block it
// Lesson: lessons/P1-async-await/03-cooperative-pool.md
// Test:   swift test --filter P1_03

/// A modern async API (don't edit).
public enum PriceAPI {
    public static func price(for sku: String) async -> Int {
        await suspend(ms: 20)
        return sku.count * 10
    }
}

public enum P1_03 {
    /// A sync wrapper someone wrote so older sync code could call the async API.
    /// "Works fine" when you try it once by hand.
    ///
    /// The compiler forbids `semaphore.wait()` directly inside an async function...
    /// but it can't see that this SYNC function is being called FROM async code.
    static func priceBlocking(_ sku: String) -> Int {
        let done = DispatchSemaphore(value: 0)
        let result = Locked(0)
        Task {
            result.value = await PriceAPI.price(for: sku)
            done.signal()
        }
        // Real code would say `done.wait()` and freeze forever.
        // We give up after 1s so your test run doesn't hang.
        _ = done.wait(timeout: .now() + 1)
        return result.value
    }

    /// Sum of the prices of all `skus`.
    ///
    /// BUG: each call to `priceBlocking` parks a cooperative-pool thread while it waits for a Task
    /// that itself needs a pool thread to run. With enough concurrent callers, every pool thread is
    /// parked waiting and no thread is left to run the inner Tasks → deadlock (here: 1s timeouts, wrong sums).
    ///
    /// TODO: async code should simply `await` async code. Remove the blocking bridge.
    public static func total(for skus: [String]) async -> Int {
        var sum = 0
        for sku in skus {
            sum += priceBlocking(sku)
        }
        return sum
    }
}
