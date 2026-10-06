import LabKit

// P3.04 — SOLUTION. Bounded concurrency: at most N in flight
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
        await withTaskGroup(of: (Int, String).self) { group in
            var nextIndex = 0

            func startNext() {
                guard nextIndex < ids.count else { return }
                let index = nextIndex
                let id = ids[index]
                nextIndex += 1
                group.addTask { (index, await downloader.download(id)) } // carry the index for ordering
            }

            // 1. Fill the window.
            for _ in 0..<min(maxConcurrent, ids.count) { startNext() }

            // 2. Each time one finishes, start exactly one more. In flight never exceeds maxConcurrent.
            var results = [String?](repeating: nil, count: ids.count)
            while let (index, file) = await group.next() {
                results[index] = file
                startNext()
            }
            return results.map { $0! }
        }
    }
}
