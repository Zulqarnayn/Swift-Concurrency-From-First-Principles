import LabKit

// P3.05 — SOLUTION. DiscardingTaskGroup and long-running work
// Lesson: lessons/P3-structured/05-discarding-task-group.md
// Test:   swift test --filter P3_05

public enum P3_05 {
    /// A tiny "server": handle every incoming request CONCURRENTLY (one child task per request).
    /// Return only when the request stream has ended AND every request has been handled.
    ///
    /// BUG: handles requests one at a time.
    /// TODO: one child per request, in a task group that doesn't pile up results it will never read.
    public static func serve(
        _ requests: AsyncStream<Int>,
        handler: @escaping @Sendable (Int) async -> Void
    ) async {
        // DiscardingTaskGroup: children's results are thrown away as soon as they finish, so a server
        // handling millions of requests doesn't accumulate them (a TaskGroup keeps every result until
        // you call next()). The group still waits for all children before returning.
        await withDiscardingTaskGroup { group in
            for await request in requests {
                group.addTask { await handler(request) }
            }
        }
    }
}
