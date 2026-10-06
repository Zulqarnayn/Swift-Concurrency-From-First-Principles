// FLAGS: -swift-version 6 -enable-upcoming-feature NonisolatedNonsendingByDefault
// EXPECT: error: 'async' call in a function that does not support concurrency
// EXPECT: error: expression is 'async' but is not marked with 'await'
//
// Lesson P1.01. PREDICT which lines fail to compile, and why, before running:
//   scripts/typecheck.sh ConcurrencyLab/Diagnostics/P1_01_async_from_sync.swift

func fetchScore() async -> Int { 42 }

// 1. A sync function calls an async function.
func syncCaller() -> Int {
    return await fetchScore()
}

// 2. An async function calls an async function, but forgets `await`.
func asyncCallerWithoutAwait() async -> Int {
    return fetchScore()
}

// 3. An async function calls a SYNC function. Is `await` needed? Allowed?
func plainSync() -> Int { 1 }
func asyncCallsSync() async -> Int {
    return plainSync()
}

// 4. A sync function STARTS async work without waiting for it.
func syncStartsTask() {
    Task {
        let score = await fetchScore()
        print(score)
    }
}
