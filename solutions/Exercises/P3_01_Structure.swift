import LabKit

// P3.01 — SOLUTION. What "structured" means
// Lesson: lessons/P3-structured/01-structured-concurrency.md
// Test:   swift test --filter P3_01

public final class DashboardLoader: Sendable {
    public let log = EventLog()

    public init() {}

    /// A fake fetch (don't edit). Logs "<part> done", or "<part> cancelled" if its task is cancelled.
    func fetch(_ part: String, ms: Int) async {
        do {
            try await Task.sleep(for: .milliseconds(ms))
            log.add("\(part) done")
        } catch {
            log.add("\(part) cancelled")
        }
    }

    /// Loads "profile" (60ms) and "feed" (80ms) CONCURRENTLY.
    /// Contract:
    ///  - when `load()` returns, both parts have finished (no work outlives the call)
    ///  - if the task calling `load()` is cancelled, both parts are cancelled
    ///
    /// BUG: unstructured children. `load()` returns immediately, and cancelling the caller doesn't reach them.
    /// TODO: make the children STRUCTURED.
    public func load() async {
        // Child tasks of the CURRENT task: they run concurrently, they're cancelled when the caller
        // is cancelled, and `load()` can't return until both are done (the implicit await at scope end
        // — here made explicit).
        async let profile: Void = fetch("profile", ms: 60)
        async let feed: Void = fetch("feed", ms: 80)
        _ = await (profile, feed)
        // (A TaskGroup works equally well; async let is the natural fit for a FIXED number of children.)
    }
}
