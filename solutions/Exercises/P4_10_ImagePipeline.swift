import Foundation
import LabKit

// P4.10 — SOLUTION. An image pipeline: dedupe + concurrency limit + LRU cache
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
    private var recency: [Int] = []                          // LRU order: front = least recently used
    private var inFlight: [Int: Task<Data, any Error>] = [:] // (1) dedupe
    private var freeSlots: Int                               // (2) download limit...
    private var slotWaiters: [CheckedContinuation<Void, Never>] = [] // ...as a tiny async semaphore

    public init(server: FakeImageServer, maxConcurrentDownloads: Int, cacheCapacity: Int) {
        self.server = server
        self.maxConcurrentDownloads = maxConcurrentDownloads
        self.cacheCapacity = cacheCapacity
        freeSlots = maxConcurrentDownloads
    }

    public func image(_ id: Int) async throws -> Data {
        if let hit = cache[id] {               // hits never wait for a download slot
            touch(id)
            return hit
        }
        if let running = inFlight[id] {        // join the existing download
            return try await running.value
        }
        let task = Task {                      // captures self → runs on this actor between awaits
            await self.acquireSlot()
            defer { self.releaseSlot() }
            return try await self.server.download(id)
        }
        inFlight[id] = task                    // published before the first suspension point
        defer { inFlight[id] = nil }
        let data = try await task.value        // failure: not cached, next request retries
        store(id, data)
        return data
    }

    /// Ids currently cached, from least to most recently used. (For tests.)
    public var cachedIDs: [Int] {
        recency
    }

    // MARK: LRU (3)

    private func touch(_ id: Int) {
        recency.removeAll { $0 == id }
        recency.append(id)
    }

    private func store(_ id: Int, _ data: Data) {
        cache[id] = data
        touch(id)
        while recency.count > cacheCapacity {
            cache[recency.removeFirst()] = nil
        }
        // (O(n) recency list: fine for a lab. Production: dictionary + doubly linked list, or NSCache.)
    }

    // MARK: Download slots (2)

    private func acquireSlot() async {
        if freeSlots > 0 {
            freeSlots -= 1
            return
        }
        await withCheckedContinuation { slotWaiters.append($0) }
    }

    private func releaseSlot() {
        if slotWaiters.isEmpty { freeSlots += 1 } else { slotWaiters.removeFirst().resume() }
    }
}
