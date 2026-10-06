// P7.04 — SOLUTION. Timed kata (25 min): concurrent processing, in-order delivery
// Lesson: lessons/P7-interview/04-kata-ordered-pipeline.md
// Test:   swift test --filter P7_04

public enum P7_04 {
    /// Transform every input CONCURRENTLY (at most `maxConcurrent` in flight), but call `emit` with the
    /// results in INPUT order — and as early as possible: result k is emitted as soon as results 0…k exist
    /// (don't wait for everything to finish first). Returns after the last emit.
    public static func mapOrdered(
        _ inputs: [Int],
        maxConcurrent: Int,
        transform: @escaping @Sendable (Int) async -> Int,
        emit: @escaping @Sendable (Int) -> Void
    ) async {
        await withTaskGroup(of: (Int, Int).self) { group in
            var next = 0
            func startNext() {
                guard next < inputs.count else { return }
                let index = next
                let input = inputs[index]
                next += 1
                group.addTask { (index, await transform(input)) }
            }
            for _ in 0..<min(maxConcurrent, inputs.count) { startNext() }

            // Results arrive in completion order. Park early arrivals in a buffer, and flush the
            // contiguous prefix whenever the next index we owe is available — "as soon as possible".
            var buffer: [Int: Int] = [:]
            var nextToEmit = 0
            while let (index, output) = await group.next() {
                buffer[index] = output
                while let ready = buffer.removeValue(forKey: nextToEmit) {
                    emit(ready)
                    nextToEmit += 1
                }
                startNext()
            }
            // Note the trade-off: with a window of N, one slow item can make the buffer hold up to
            // N-1 finished results (head-of-line blocking). Bounded by the window, so memory is bounded.
        }
    }
}
