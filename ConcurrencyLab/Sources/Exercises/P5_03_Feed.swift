import LabKit

// P5.03 — Bug hunt: "duplicate posts while scrolling; old posts reappear after pull-to-refresh"
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

    public init(server: FeedServer) {
        self.server = server
    }

    /// Called by the list whenever the last cells become visible (it can fire several times quickly).
    public func loadNextPage() async {
        let page = nextPage
        guard let items = try? await server.page(page) else { return }
        posts += items
        nextPage = page + 1
    }

    /// Pull-to-refresh: start over from page 1.
    public func refresh() async {
        posts = []
        nextPage = 1
        await loadNextPage()
    }
}
