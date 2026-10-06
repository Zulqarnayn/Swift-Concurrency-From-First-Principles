import LabKit

// P3.04 — Bounded concurrency: at most N in flight
// Lesson: lessons/P3-structured/04-bounded-concurrency.md
// Test:   swift test --filter P3_04

/// Fake downloader (don't edit). 20ms per download.
public final class BoundedDownloader: Sendable {
    public let meter = ConcurrencyMeter()
    public init() {}

    public func download(_ id: Int) async -> String {
        meter.enter()
        try? await Task.sleep(for: .milliseconds(20))
        meter.leave()
        return "file-\(id)"
    }
}

public enum P3_04 {
    /// Download everything with AT MOST `maxConcurrent` downloads in flight at any moment.
    /// Return the results in the SAME ORDER as `ids` (not completion order).
    ///
    /// BUG: unbounded (all at once) and results come back in completion order.
    /// TODO: sliding window — start `maxConcurrent`, then start one more each time one finishes.
    public static func downloadAll(_ ids: [Int], maxConcurrent: Int, using downloader: BoundedDownloader) async -> [String] {
        await withTaskGroup(of: String.self) { group in
            for id in ids {
                group.addTask { await downloader.download(id) }
            }
            var results: [String] = []
            for await file in group { results.append(file) }
            return results
        }
    }
}
