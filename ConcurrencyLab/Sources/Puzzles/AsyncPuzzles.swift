import LabKit

// P1.10 — "What does this print?" for async/await.
// Read each puzzle, write your prediction in Exercises/P1_10_Predictions.swift, then:
//     swift test --filter P1_10      (grades your predictions)
//     swift run lab p1.10            (shows the real answers)
// Every puzzle is deterministic.

public enum AsyncPuzzles {
    public static let all: [(String, @MainActor () async -> [String])] = [
        ("puzzle1", puzzle1), ("puzzle2", puzzle2), ("puzzle3", puzzle3), ("puzzle4", puzzle4),
        ("puzzle5", puzzle5), ("puzzle6", puzzle6), ("puzzle7", puzzle7), ("puzzle8", puzzle8),
    ]

    /// Puzzle 1 — when does a Task's body run?
    @MainActor
    public static func puzzle1() async -> [String] {
        let log = EventLog()
        log.add("A")
        let task = Task { log.add("B") }
        log.add("C")
        await task.value
        return log.all
    }

    /// Puzzle 2 — Task.immediate.
    @MainActor
    public static func puzzle2() async -> [String] {
        let log = EventLog()
        log.add("A")
        let task = Task.immediate {
            log.add("B")
            await Task.yield()
            log.add("D")
        }
        log.add("C")
        await task.value
        return log.all
    }

    /// Puzzle 3 — two tasks on the main actor, interleaving at awaits.
    @MainActor
    public static func puzzle3() async -> [String] {
        let log = EventLog()
        let t1 = Task {
            log.add("1a")
            await suspend(ms: 60)
            log.add("1b")
        }
        let t2 = Task {
            log.add("2a")
            await suspend(ms: 10)
            log.add("2b")
        }
        await t1.value
        await t2.value
        return log.all
    }

    /// Puzzle 4 — does `await` always suspend?
    @MainActor
    public static func puzzle4() async -> [String] {
        let log = EventLog()
        log.add("A")
        let task = Task { log.add("B") }
        await sameActorWork(log)
        log.add("C")
        await task.value
        return log.all
    }

    @MainActor
    static func sameActorWork(_ log: EventLog) async {
        log.add("X")
    }

    /// Puzzle 5 — bufferingNewest(2), and nobody reads until the end.
    @MainActor
    public static func puzzle5() async -> [String] {
        let log = EventLog()
        let (stream, continuation) = AsyncStream.makeStream(of: Int.self, bufferingPolicy: .bufferingNewest(2))
        for i in 1...4 { continuation.yield(i) }
        continuation.finish()
        for await value in stream { log.add("\(value)") }
        return log.all
    }

    /// Puzzle 6 — breaking out of a for-await loop while the `stream` variable is still alive.
    @MainActor
    public static func puzzle6() async -> [String] {
        let log = EventLog()
        let (stream, continuation) = AsyncStream.makeStream(of: Int.self)
        continuation.onTermination = { _ in log.add("onTermination") }
        continuation.yield(1)
        continuation.yield(2)
        continuation.yield(3)
        for await value in stream {
            log.add("\(value)")
            if value == 2 { break }
        }
        log.add("after loop")
        let result = continuation.yield(4)
        if case .terminated = result { log.add("yield 4: terminated") } else { log.add("yield 4: enqueued") }
        return log.all
    }

    /// Puzzle 7 — same as puzzle 6, but the stream is created right in the `for` statement.
    @MainActor
    public static func puzzle7() async -> [String] {
        let log = EventLog()
        let saved = Locked<AsyncStream<Int>.Continuation?>(nil)
        func makeNumbers() -> AsyncStream<Int> {
            AsyncStream { continuation in
                continuation.onTermination = { _ in log.add("onTermination") }
                saved.value = continuation
                continuation.yield(1)
                continuation.yield(2)
                continuation.yield(3)
            }
        }
        for await value in makeNumbers() {
            log.add("\(value)")
            if value == 2 { break }
        }
        log.add("after loop")
        let result = saved.value!.yield(4)
        if case .terminated = result { log.add("yield 4: terminated") } else { log.add("yield 4: enqueued") }
        return log.all
    }

    /// Puzzle 8 — an error thrown in a Task that is never awaited.
    @MainActor
    public static func puzzle8() async -> [String] {
        struct Oops: Error {}
        let log = EventLog()
        log.add("start")
        Task {
            log.add("task throws")
            throw Oops()
        }
        await suspend(ms: 30)
        log.add("end")
        return log.all
    }
}
