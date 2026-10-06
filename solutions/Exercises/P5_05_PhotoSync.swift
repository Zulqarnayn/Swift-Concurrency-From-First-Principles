import Dispatch
import Foundation
import LabKit

// P5.05 — SOLUTION. Bug hunt: "photo sync freezes for seconds when many photos are queued"
// Lesson: lessons/P5-bug-zoo/05-pool-starvation.md
// Repro:  swift run lab p5.05  /  scripts/strict-pool.sh p5.05      Test: swift test --filter P5_05

/// A legacy photo library API (don't edit): synchronous, does real blocking disk I/O (~20ms).
public enum LegacyPhotoLibrary {
    public static func thumbnailData(for id: Int) -> Data {
        usleep(20_000)
        return Data("thumb-\(id)".utf8)
    }
}

/// Modern network status API (don't edit).
public enum NetworkMonitor {
    public static func isOnWiFi() async -> Bool {
        await suspend(ms: 5)
        return true
    }
}

public final class PhotoSyncService: Sendable {
    public let uploaded = CallCounter()

    public init() {}

    /// Uploads every photo. Returns how many were uploaded.
    public func sync(_ ids: [Int]) async -> Int {
        var count = 0
        for id in ids {
            guard await NetworkMonitor.isOnWiFi() else { continue }
            let data = await thumbnail(id)
            await upload(data)
            await pace()
            count += 1
        }
        return count
    }

    // ROOT CAUSE #1 (the big one): `wifiAvailable()` bridged async → sync with a semaphore. Called from
    // async code, it parked a cooperative-pool thread waiting for a Task that needed a pool thread.
    // Enough concurrent syncs → every pool thread parked → 1s timeouts → "freezes for seconds", and the
    // timeout made it return `false`, so photos were silently SKIPPED. The 1s timeout hid a deadlock.
    // FIX: delete the bridge; just `await` the async API.

    // ROOT CAUSE #2: a synchronous, BLOCKING legacy I/O call ran on a cooperative-pool thread.
    // FIX: you can't make it non-blocking, but you can move it OFF the pool: GCD threads exist for
    // exactly this (the pool must only run code that makes forward progress, P1.03).
    private static let ioQueue = DispatchQueue(label: "photo-io", attributes: .concurrent)

    private func thumbnail(_ id: Int) async -> Data {
        await withCheckedContinuation { continuation in
            Self.ioQueue.async { continuation.resume(returning: LegacyPhotoLibrary.thumbnailData(for: id)) }
        }
    }

    private func upload(_ data: Data) async {
        await suspend(ms: 20)
        uploaded.increment()
    }

    /// Be gentle with the server.
    // ROOT CAUSE #3: `usleep` blocked a pool thread. FIX: suspend instead.
    private func pace() async {
        try? await Task.sleep(for: .milliseconds(5))
    }
}
