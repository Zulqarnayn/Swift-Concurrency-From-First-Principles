import Foundation
import LabKit

// P2.04 — SOLUTION. Actor reentrancy
// Lesson: lessons/P2-isolation/04-actor-reentrancy.md
// Test:   swift test --filter P2_04

public struct DownloadError: Error, Equatable {}

/// Fake network (don't edit). Counts downloads. URLs starting with "bad" fail.
public final class FakeDownloader: Sendable {
    private let calls = CallCounter()
    public init() {}

    public func download(_ url: String) async throws -> Data {
        calls.increment()
        await suspend(ms: 50)
        if url.hasPrefix("bad") { throw DownloadError() }
        return Data(url.utf8)
    }

    public var downloads: Int { calls.count }
}

public actor ImageCache {
    private let downloader: FakeDownloader
    private var cache: [String: Data] = [:]
    private var inFlight: [String: Task<Data, any Error>] = [:]

    public init(downloader: FakeDownloader) {
        self.downloader = downloader
    }

    /// Returns the image for `url`, downloading it at most once.
    ///
    /// BUG: reentrancy. 10 callers ask for the same URL at once. Each one checks the cache (empty),
    /// then suspends at `await download` — and while it's suspended, the actor happily runs the next
    /// caller, who also sees an empty cache. 10 downloads.
    ///
    /// TODO:
    ///  - concurrent requests for the same URL share ONE download (hint: remember the in-flight `Task`)
    ///  - a failed download is NOT cached: the next request tries again
    public func image(for url: String) async throws -> Data {
        if let cached = cache[url] { return cached }

        // Someone already started this download: join it instead of starting another.
        if let running = inFlight[url] {
            return try await running.value
        }

        // Record the in-flight work BEFORE the first suspension point. Everything from the cache check
        // to this line is synchronous, so no other call can interleave: this is the critical section.
        let downloader = self.downloader
        let task = Task { try await downloader.download(url) }
        inFlight[url] = task

        do {
            let data = try await task.value
            // After an await, never assume: state may have changed. Here we only write our own result.
            cache[url] = data
            inFlight[url] = nil
            return data
        } catch {
            inFlight[url] = nil // don't cache failures: the next caller retries
            throw error
        }
    }
}
