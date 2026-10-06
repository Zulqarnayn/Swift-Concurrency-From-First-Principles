// FLAGS: -swift-version 6 -enable-upcoming-feature NonisolatedNonsendingByDefault
// EXPECT: error: passing closure as a 'sending' parameter risks causing data races between code in the current task and concurrent execution of the closure
// EXPECT: error: sending 'total' risks causing data races
//
// Lesson P3.03. Collecting results from concurrent children. Which versions compile? (cases 1, 2, 4)
//   scripts/typecheck.sh ConcurrencyLab/Diagnostics/P3_03a_shared_mutation.swift

func fetch(_ id: Int) async -> String { "item \(id)" }

// 1. Children append to a shared local array.
func collectByMutation(_ ids: [Int]) async -> [String] {
    var results: [String] = []
    await withTaskGroup(of: Void.self) { group in
        for id in ids {
            group.addTask { results.append(await fetch(id)) }
        }
    }
    return results
}

// 2. Children RETURN values; the parent collects them.
func collectByReturning(_ ids: [Int]) async -> [Int: String] {
    await withTaskGroup(of: (Int, String).self) { group in
        for id in ids {
            group.addTask { (id, await fetch(id)) }
        }
        var results: [Int: String] = [:]
        for await (id, value) in group { results[id] = value }
        return results
    }
}

// 4. async let mutates a captured var.
func asyncLetMutation() async -> Int {
    var total = 0
    async let a: Void = { total += 1 }()
    await a
    return total
}

// 5. Same as 4, but the parent touches `total` while the child may be running.
func asyncLetMutationRacing() async -> Int {
    var total = 0
    async let a: Void = { total += 1 }()
    total += 10
    await a
    return total
}
