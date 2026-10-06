import Foundation
import LabKit

// P4.10 — An image pipeline: dedupe + concurrency limit + LRU cache
// Lesson: lessons/P4-classics/10-image-pipeline.md
// Test:   swift test --filter P4_10

/// Fake image server (don't edit). 30ms per download.
public final class FakeImageServer: Sendable {
    public let meter = ConcurrencyMeter()
    public let downloads = CallCounter()
    public init() {}

    public func download(_ id: Int) async throws -> Data {
        downloads.increment()
        meter.enter()
        defer { meter.leave() }
        try await Task.sleep(for: .milliseconds(30))
        return Data("image-\(id)".utf8)
    }
}

/// Everything from P2.04 + P3.04 + P4.04 in one real component.
/// Requirements:
///  1. concurrent requests for the same id share ONE download (dedupe; failures not cached)
///  2. at most `maxConcurrentDownloads` downloads in flight at once (cache hits never wait)
///  3. memory cache holds at most `cacheCapacity` images; evict the LEAST RECENTLY USED
///
/// BUG: none of the three. TODO: all three.
public actor ImagePipeline {
    private let server: FakeImageServer
    public let maxConcurrentDownloads: Int
    public let cacheCapacity: Int
    private var cache: [Int: Data] = [:]

    public init(server: FakeImageServer, maxConcurrentDownloads: Int, cacheCapacity: Int) {
        self.server = server
        self.maxConcurrentDownloads = maxConcurrentDownloads
        self.cacheCapacity = cacheCapacity
    }

    public func image(_ id: Int) async throws -> Data {
        if let hit = cache[id] { return hit }
        let data = try await server.download(id)
        cache[id] = data
        return data
    }

    /// Ids currently cached, from least to most recently used. (For tests.)
    public var cachedIDs: [Int] {
        cache.keys.sorted()
    }
}
