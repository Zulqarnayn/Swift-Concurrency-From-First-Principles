// FLAGS: -swift-version 6 -enable-upcoming-feature NonisolatedNonsendingByDefault
// EXPECT: error: type 'Thumbnail' does not conform to the 'Sendable' protocol
//
// Lesson P3.03. Collecting results from concurrent children. Can a child task return a non-Sendable class?
//   scripts/typecheck.sh ConcurrencyLab/Diagnostics/P3_03b_child_results.swift

final class Thumbnail { var url = "" }            // not Sendable

// 3. Children return a non-Sendable class.
func collectClasses(_ ids: [Int]) async -> [Thumbnail] {
    await withTaskGroup(of: Thumbnail.self) { group in
        for _ in ids { group.addTask { Thumbnail() } }
        var all: [Thumbnail] = []
        for await t in group { all.append(t) }
        return all
    }
}

