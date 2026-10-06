// FLAGS: -swift-version 6 -enable-upcoming-feature NonisolatedNonsendingByDefault
// FORBID: @unchecked | nonisolated(unsafe) | @preconcurrency | @MainActor
//
// P2.11 — Global and static state.
//   scripts/fixme.sh ConcurrencyLab/Fixme/P2_11_globals.swift
// Rules: `trackRequest` is called from many threads and must stay SYNCHRONOUS (no async, no await).
// No escape hatches, and no @MainActor (these are called from background code).

import Synchronization

/// Counts requests from any thread.
var requestCount = 0

enum Endpoints {
    /// Set once at build time, never changed.
    static var baseURL = "https://api.example.com"
}

final class Analytics {
    static let shared = Analytics()
    private var events: [String] = []

    func log(_ event: String) { events.append(event) }
    var eventCount: Int { events.count }
}

let defaultHeaders: [String: String] = ["Accept": "application/json"]

func trackRequest(_ path: String) -> String {
    requestCount += 1
    Analytics.shared.log(path)
    return Endpoints.baseURL + path
}
