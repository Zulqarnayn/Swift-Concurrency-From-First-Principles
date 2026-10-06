// FLAGS: -swift-version 6 -enable-upcoming-feature NonisolatedNonsendingByDefault -enable-upcoming-feature InferIsolatedConformances
// FORBID: @unchecked | nonisolated(unsafe) | @preconcurrency | MainActor.run
//
// P2.12 — Protocols and isolation.
//   scripts/fixme.sh ConcurrencyLab/Fixme/P2_12_conformances.swift
// `Article` is UI state, so it stays @MainActor. But its Cacheable and Hashable conformances are needed
// by background code (DiskCache runs @concurrent). Make it compile WITHOUT changing DiskCache or the
// @concurrent functions. Think: which members can be safely used from any thread? Why?

protocol Cacheable {
    var cacheKey: String { get }
}

@MainActor
final class Article: Cacheable, Hashable {
    let id: Int
    var title: String

    init(id: Int, title: String) {
        self.id = id
        self.title = title
    }

    var cacheKey: String { "article-\(id)" }

    static func == (lhs: Article, rhs: Article) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
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
