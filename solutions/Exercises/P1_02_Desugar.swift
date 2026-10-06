import Dispatch

// P1.02 — SOLUTION. Under the hood: an async function is a chain of continuations
// Lesson: lessons/P1-async-await/02-under-the-hood.md
// Test:   swift test --filter P1_02

public struct Cart: Sendable {
    public let id: String
    public let prices: [Int]
}

public struct Payment: Sendable {
    public let id: String
}

public struct Receipt: Equatable, Sendable {
    public let paymentID: String
    public let total: Int
    public init(paymentID: String, total: Int) {
        self.paymentID = paymentID
        self.total = total
    }
}

public enum ShopError: Error, Equatable, Sendable {
    case cartNotFound
    case cardDeclined
}

// MARK: - Fake shop backend (don't edit)

public enum ShopAPI {
    /// "c1" → [10, 20, 30].  "big" → [80, 50].  Anything else → .cartNotFound.
    public static func fetchCart(_ id: String, completion: @escaping @Sendable (Result<Cart, ShopError>) -> Void) {
        DispatchQueue.global().asyncAfter(deadline: .now() + .milliseconds(5)) {
            switch id {
            case "c1": completion(.success(Cart(id: id, prices: [10, 20, 30])))
            case "big": completion(.success(Cart(id: id, prices: [80, 50])))
            default: completion(.failure(.cartNotFound))
            }
        }
    }

    /// Amounts over 100 are declined. Otherwise the payment id is "pay-<amount>".
    public static func charge(_ amount: Int, completion: @escaping @Sendable (Result<Payment, ShopError>) -> Void) {
        DispatchQueue.global().asyncAfter(deadline: .now() + .milliseconds(5)) {
            if amount > 100 {
                completion(.failure(.cardDeclined))
            } else {
                completion(.success(Payment(id: "pay-\(amount)")))
            }
        }
    }

    // Async versions. (How these are built is P1.05's topic — peek if you're curious.)
    public static func fetchCart(_ id: String) async throws -> Cart {
        try await withCheckedThrowingContinuation { c in fetchCart(id) { c.resume(with: $0) } }
    }

    public static func charge(_ amount: Int) async throws -> Payment {
        try await withCheckedThrowingContinuation { c in charge(amount) { c.resume(with: $0) } }
    }
}

public enum P1_02 {
    /// The async version. Read it carefully. Where can it suspend? What must survive each suspension?
    public static func checkout(cartID: String) async throws -> Receipt {
        let cart = try await ShopAPI.fetchCart(cartID)  // suspension point #1
        let total = cart.prices.reduce(0, +)
        let payment = try await ShopAPI.charge(total)   // suspension point #2 — `total` must survive it
        return Receipt(paymentID: payment.id, total: total)
    }

    /// TODO: the SAME logic using ONLY the callback versions of ShopAPI.
    /// You are doing by hand what the compiler does for `checkout`: every `await` becomes
    /// "the rest of the function, packaged as a closure" (a continuation).
    ///
    /// Contract: call `completion` exactly once, with the receipt or the first error.
    public static func checkoutCPS(
        cartID: String,
        completion: @escaping @Sendable (Result<Receipt, ShopError>) -> Void
    ) {
        // Part 1: everything before the first `await`.
        ShopAPI.fetchCart(cartID) { cartResult in
            // Continuation #1: "the rest of checkout after fetchCart returns".
            switch cartResult {
            case .failure(let error):
                completion(.failure(error)) // `throw` = call the continuation with an error, then stop
            case .success(let cart):
                let total = cart.prices.reduce(0, +)
                // `total` must outlive this closure → it is captured by the next one.
                // In the async version the compiler stores it in the task's heap-allocated async frame.
                ShopAPI.charge(total) { paymentResult in
                    // Continuation #2: "the rest after charge returns".
                    switch paymentResult {
                    case .failure(let error):
                        completion(.failure(error))
                    case .success(let payment):
                        completion(.success(Receipt(paymentID: payment.id, total: total)))
                    }
                }
            }
        }
    }
}
