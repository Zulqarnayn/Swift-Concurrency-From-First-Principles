import Dispatch
import Foundation
import LabKit

// P5.05 — Bug hunt: "photo sync freezes for seconds when many photos are queued"
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
            guard wifiAvailable() else { continue }
            let data = thumbnail(id)
            await upload(data)
            pace()
            count += 1
        }
        return count
    }

    private func wifiAvailable() -> Bool {
        let done = DispatchSemaphore(value: 0)
        let result = Locked(false)
        Task {
            result.value = await NetworkMonitor.isOnWiFi()
            done.signal()
        }
        _ = done.wait(timeout: .now() + 1) // added after the "infinite hang" bug report; "fixed" it
        return result.value
    }

    private func thumbnail(_ id: Int) -> Data {
        LegacyPhotoLibrary.thumbnailData(for: id)
    }

    private func upload(_ data: Data) async {
        await suspend(ms: 20)
        uploaded.increment()
    }

    /// Be gentle with the server.
    private func pace() {
        usleep(5_000)
    }
}
