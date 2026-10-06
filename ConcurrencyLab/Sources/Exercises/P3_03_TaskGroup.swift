import LabKit

// P3.03 — TaskGroup and ThrowingTaskGroup
// Lesson: lessons/P3-structured/03-task-groups.md
// Test:   swift test --filter P3_03

public struct ThumbnailMissing: Error, Equatable {
    public let id: Int
    public init(id: Int) { self.id = id }
}

/// Fake thumbnail service (don't edit). 100ms per call; negative ids fail after 10ms.
public final class ThumbnailAPI: Sendable {
    public let meter = ConcurrencyMeter()
    public let cancellations = CallCounter()
    public init() {}

    public func fetch(_ id: Int) async throws -> String {
        meter.enter()
        defer { meter.leave() }
        if id < 0 {
            try await Task.sleep(for: .milliseconds(10))
            throw ThumbnailMissing(id: id)
        }
        do {
            try await Task.sleep(for: .milliseconds(100))
        } catch {
            cancellations.increment()
            throw error
        }
        return "thumb-\(id).png"
    }
}

public enum P3_03 {
    /// Fetch every thumbnail CONCURRENTLY. Skip the ones that fail. Result: [id: url].
    /// BUG: sequential. TODO: TaskGroup.
    public static func thumbnails(for ids: [Int], api: ThumbnailAPI) async -> [Int: String] {
        var result: [Int: String] = [:]
        for id in ids {
            if let url = try? await api.fetch(id) { result[id] = url }
        }
        return result
    }

    /// All-or-nothing, CONCURRENTLY: if any fetch fails, throw that error right away
    /// and cancel the fetches still running. (Careful: one way of waiting for a group does NOT cancel.)
    /// BUG: sequential. TODO: ThrowingTaskGroup.
    public static func requireAll(_ ids: [Int], api: ThumbnailAPI) async throws -> [Int: String] {
        var result: [Int: String] = [:]
        for id in ids {
            result[id] = try await api.fetch(id)
        }
        return result
    }
}
