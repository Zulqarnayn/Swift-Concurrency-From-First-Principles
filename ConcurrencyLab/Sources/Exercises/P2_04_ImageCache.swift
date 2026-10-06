import Foundation
import LabKit

// P2.04 — Actor reentrancy
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
        let data = try await downloader.download(url)
        cache[url] = data
        return data
    }
}
