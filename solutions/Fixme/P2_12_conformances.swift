// FLAGS: -swift-version 6 -enable-upcoming-feature NonisolatedNonsendingByDefault -enable-upcoming-feature InferIsolatedConformances
// FORBID: @unchecked | nonisolated(unsafe) | @preconcurrency | MainActor.run
//
// P2.12 — SOLUTION

protocol Cacheable {
    var cacheKey: String { get }
}

@MainActor
final class Article: nonisolated Cacheable, nonisolated Hashable {
    let id: Int       // immutable + Sendable → safe to read from ANY isolation
    var title: String // mutable UI state → stays main-actor-only

    init(id: Int, title: String) {
        self.id = id
        self.title = title
    }

    // Two steps (SE-0470):
    //  1. `nonisolated Cacheable, nonisolated Hashable` in the conformance list: with
    //     InferIsolatedConformances, a @MainActor type's conformances are @MainActor by default.
    //     Writing `nonisolated` asks for a conformance usable from ANY isolation.
    //  2. The compiler then requires every witness to be nonisolated too. That's truthful here:
    //     they only read `id`, a `let` of a Sendable type, which is safe from any thread.
    nonisolated var cacheKey: String { "article-\(id)" }

    nonisolated static func == (lhs: Article, rhs: Article) -> Bool { lhs.id == rhs.id }
    nonisolated func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

enum DiskCache {
    @concurrent
    static func keys(for items: [any Cacheable & Sendable]) async -> [String] {
        items.map(\.cacheKey)
    }

    @concurrent
    static func uniqueCount(_ articles: [Article]) async -> Int {
        Set(articles).count
    }
}

@MainActor
func saveAll(_ articles: [Article]) async -> (keys: [String], unique: Int) {
    let keys = await DiskCache.keys(for: articles)
    let unique = await DiskCache.uniqueCount(articles)
    return (keys, unique)
}
