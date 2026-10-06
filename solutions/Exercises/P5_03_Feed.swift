import LabKit

// P5.03 — SOLUTION. Bug hunt: "duplicate posts while scrolling; old posts reappear after pull-to-refresh"
// Lesson: lessons/P5-bug-zoo/03-pagination.md
// Repro:  swift run lab p5.03        Test: swift test --filter P5_03

/// Fake feed backend (don't edit). Page n returns ["p<n>-0", "p<n>-1", "p<n>-2"].
/// Latency per page is configurable so tests can force interleavings.
public final class FeedServer: Sendable {
    public let requests = EventLog()
    private let latency: @Sendable (Int) -> Int

    public init(latency: @escaping @Sendable (Int) -> Int = { _ in 20 }) {
        self.latency = latency
    }

    public func page(_ number: Int) async throws -> [String] {
        requests.add("\(number)")
        try await Task.sleep(for: .milliseconds(latency(number)))
        return (0..<3).map { "p\(number)-\($0)" }
    }
}

@MainActor
public final class FeedModel {
    public private(set) var posts: [String] = []
    private var nextPage = 1
    private let server: FeedServer
    private var loading: Task<Void, Never>?
    private var generation = 0 // bumped by refresh(): anything started before belongs to an old feed

    public init(server: FeedServer) {
        self.server = server
    }

    /// Called by the list whenever the last cells become visible (it can fire several times quickly).
    public func loadNextPage() async {
        // ROOT CAUSE #1 (duplicates): every call read the same `nextPage` before the first one finished.
        // FIX: single-flight. A load is already running → join it instead of starting another.
        if let loading {
            await loading.value
            return
        }
        let page = nextPage
        let generation = self.generation
        let task = Task {
            guard let items = try? await server.page(page) else { return }
            // ROOT CAUSE #2 (stale pages): a response from before refresh() was appended to the new feed.
            // FIX: only apply results that belong to the current generation and weren't cancelled.
            guard generation == self.generation, !Task.isCancelled else { return }
            posts += items
            nextPage = page + 1
        }
        loading = task
        await task.value
        if generation == self.generation { loading = nil } // don't clear a newer load started by refresh()
    }

    /// Pull-to-refresh: start over from page 1.
    public func refresh() async {
        loading?.cancel()
        loading = nil
        generation += 1
        posts = []
        nextPage = 1
        await loadNextPage()
    }
}
