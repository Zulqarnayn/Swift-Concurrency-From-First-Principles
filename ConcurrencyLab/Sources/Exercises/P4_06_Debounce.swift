import LabKit

// P4.06 — Debounce and throttle
// Lesson: lessons/P4-classics/06-debounce-throttle.md
// Test:   swift test --filter P4_06

/// Fake search backend (don't edit). 40ms per search; records every query it receives and every cancellation.
public final class SearchBackend: Sendable {
    public let queries = EventLog()
    public let cancelled = EventLog()
    public init() {}

    public func search(_ query: String) async throws -> [String] {
        queries.add(query)
        do {
            try await Task.sleep(for: .milliseconds(40))
        } catch {
            cancelled.add(query)
            throw error
        }
        return ["\(query)-result"]
    }
}

@MainActor
public final class DebouncedSearch {
    public private(set) var results: [String] = []
    /// Queries whose results were displayed, in order.
    public private(set) var shown: [String] = []
    public let backend: SearchBackend
    public let delay: Duration

    public init(backend: SearchBackend, delay: Duration) {
        self.backend = backend
        self.delay = delay
    }

    /// Called on every keystroke.
    ///
    /// BUG: searches on every keystroke, and stale responses can win.
    /// TODO: DEBOUNCE — search only after the user paused typing for `delay`. A new keystroke cancels
    /// both a pending (not yet started) search AND an in-flight one. Stale results never appear.
    public func queryChanged(_ query: String) {
        Task {
            let found = (try? await backend.search(query)) ?? []
            results = found
            shown.append(query)
        }
    }
}

/// THROTTLE (leading edge): run the action immediately, then ignore further submissions until `interval`
/// has passed since the last action that RAN. Returns whether this submission ran.
///
/// BUG: runs everything. TODO: throttle.
public actor Throttler {
    public let interval: Duration

    public init(interval: Duration) {
        self.interval = interval
    }

    public func submit(_ action: @Sendable () async -> Void) async -> Bool {
        await action()
        return true
    }
}
