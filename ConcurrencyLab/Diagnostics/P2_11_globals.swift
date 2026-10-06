// FLAGS: -swift-version 6 -enable-upcoming-feature NonisolatedNonsendingByDefault
// EXPECT: error: static property 'shared' is not concurrency-safe because non-'Sendable' type 'Analytics' may have shared mutable state
// EXPECT: error: var 'requestCount' is not concurrency-safe because it is nonisolated global shared mutable state
// EXPECT: error: static property 'baseURL' is not concurrency-safe because it is nonisolated global shared mutable state
//
// Lesson P2.11. Which globals does Swift 6 accept?
//   scripts/typecheck.sh ConcurrencyLab/Diagnostics/P2_11_globals.swift

final class Analytics { static let shared = Analytics(); var events: [String] = [] }

var requestCount = 0                                   // 1. mutable global
let maxRetries = 3                                     // 2. immutable global, Sendable type
struct Env { static var baseURL = "https://a.example" } // 3. mutable static
// 4. Analytics.shared: static let of a NON-Sendable class (above)
@MainActor var theme = "light"                         // 5. mutable global isolated to the main actor
nonisolated(unsafe) var legacyFlag = false             // 6. the escape hatch
