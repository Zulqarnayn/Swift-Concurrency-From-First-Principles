// FLAGS: -swift-version 6 -enable-upcoming-feature NonisolatedNonsendingByDefault
// FORBID: @unchecked | nonisolated(unsafe) | @preconcurrency | @MainActor
//
// P2.11 — SOLUTION

import Synchronization

/// Shared + mutable + must stay synchronous → an Atomic, behind a global `let`.
/// A global/static `let` is lazily initialized exactly once, thread-safely, so the binding is safe;
/// the Atomic makes the mutations safe.
let requestCount = Atomic<Int>(0)

enum Endpoints {
    /// It never changes → it's a constant. `let` of a Sendable type is always concurrency-safe.
    static let baseURL = "https://api.example.com"
}

/// A singleton is a global. `static let shared` is fine IF the type is Sendable.
/// Shared + mutable + synchronous API → protect the state with a Mutex; the class becomes Sendable for real.
/// (An `actor` would also work, but `log` would become async — breaking the "stays synchronous" rule.)
final class Analytics: Sendable {
    static let shared = Analytics()
    private let events = Mutex<[String]>([])

    func log(_ event: String) { events.withLock { $0.append(event) } }
    var eventCount: Int { events.withLock { $0.count } }
}

/// Already fine: an immutable global of a Sendable type.
let defaultHeaders: [String: String] = ["Accept": "application/json"]

func trackRequest(_ path: String) -> String {
    requestCount.add(1, ordering: .relaxed)
    Analytics.shared.log(path)
    return Endpoints.baseURL + path
}
