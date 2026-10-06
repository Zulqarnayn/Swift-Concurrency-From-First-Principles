// FLAGS: -swift-version 6
// EXPECT: error: sending 'self.store' risks causing data races
//
// Lesson P2.15. Non-Sendable first design, compiled with Swift 6.0/6.1 rules (NO NonisolatedNonsendingByDefault).
// The exact same code compiles cleanly in this package's modern targets (see Demos p2.15).
//   scripts/typecheck.sh ConcurrencyLab/Diagnostics/P2_15_nonsendable_legacy.swift

final class ImageStore {               // not Sendable, not isolated: just a class
    var cache: [String: Int] = [:]
    func load(_ key: String) async -> Int {
        cache[key] = key.count
        return key.count
    }
}

@MainActor final class ViewModel {
    let store = ImageStore()
    func refresh() async { _ = await store.load("cat") }
}
