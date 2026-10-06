// P7.03 — SOLUTION. Timed kata (25 min): parallel fetch with a limit and a deadline
// Lesson: lessons/P7-interview/03-kata-fetch-all.md
// Test:   swift test --filter P7_03

public struct DeadlineExceeded: Error, Equatable {
    public init() {}
}

public enum P7_03 {
    /// Fetch every id concurrently, with at most `maxConcurrent` fetches in flight.
    /// Return exactly ONE entry per id:
    ///  - `.success(value)` if its fetch finished in time
    ///  - `.failure(error)` if its fetch threw
    ///  - `.failure(DeadlineExceeded())` if it hadn't finished (or started) when `deadline` elapsed —
    ///    and any fetch still running at the deadline must be CANCELLED
    /// The function must return promptly at the deadline (assume fetches honor cancellation).
    public static func fetchAll(
        _ ids: [Int],
        maxConcurrent: Int,
        deadline: Duration,
        fetch: @escaping @Sendable (Int) async throws -> String
    ) async -> [Int: Result<String, any Error>] {
        enum Event: Sendable {
            case finished(Int, Result<String, any Error>)
            case deadline
        }
        var results: [Int: Result<String, any Error>] = [:]

        await withTaskGroup(of: Event.self) { group in
            // The deadline is just another child: when it finishes first, we stop.
            group.addTask {
                try? await Task.sleep(for: deadline)
                return .deadline
            }
            var next = 0
            func startNext() {
                guard next < ids.count else { return }
                let id = ids[next]
                next += 1
                group.addTask {
                    do { return .finished(id, .success(try await fetch(id))) } catch { return .finished(id, .failure(error)) }
                }
            }
            for _ in 0..<min(maxConcurrent, ids.count) { startNext() } // sliding window (P3.04)

            while let event = await group.next() {
                switch event {
                case .finished(let id, let result):
                    results[id] = result
                    if results.count == ids.count {
                        group.cancelAll() // everything done: cancel the deadline timer and return
                        return
                    }
                    startNext()
                case .deadline:
                    group.cancelAll() // cancel every fetch still running (they're cooperative)
                    return            // the group still AWAITS them before returning (P3.08's caveat)
                }
            }
        }
        // Anything without a result (running at the deadline, or never started) timed out.
        for id in ids where results[id] == nil {
            results[id] = .failure(DeadlineExceeded())
        }
        return results
    }
}
