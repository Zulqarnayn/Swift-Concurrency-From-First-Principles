import Dispatch
import LabKit

// P7.02 — the "explain the output" marathon. Mixed GCD, async/await, actors, structured concurrency.
// Every puzzle is deterministic. Predict in Exercises/P7_02_Marathon.swift.

public enum MarathonPuzzles {
    public static let all: [(String, @MainActor () async -> [String])] = [
        ("puzzle1", puzzle1), ("puzzle2", puzzle2), ("puzzle3", puzzle3), ("puzzle4", puzzle4), ("puzzle5", puzzle5),
        ("puzzle6", puzzle6), ("puzzle7", puzzle7), ("puzzle8", puzzle8), ("puzzle9", puzzle9), ("puzzle10", puzzle10),
    ]

    /// 1 — GCD: async onto the serial queue you're running on, then sync onto it from outside.
    @MainActor public static func puzzle1() async -> [String] {
        await onDedicatedThread {
            let log = EventLog()
            let q = DispatchQueue(label: "serial")
            q.sync {
                log.add("a")
                q.async { log.add("b") }
                log.add("c")
            }
            q.sync { log.add("d") }
            return log.all
        }!
    }

    /// 2 — main actor: a queued Task, then awaiting a @concurrent function that sleeps.
    @concurrent static func concurrentPause() async { await suspend(ms: 20) }

    @MainActor public static func puzzle2() async -> [String] {
        let log = EventLog()
        log.add("A")
        let task = Task { log.add("B") }
        await concurrentPause()
        log.add("C")
        await task.value
        return log.all
    }

    /// 3 — async let: who finishes when?
    static func work(_ name: String, ms: Int, _ log: EventLog) async -> String {
        await suspend(ms: ms)
        log.add("\(name) done")
        return name
    }

    @MainActor public static func puzzle3() async -> [String] {
        let log = EventLog()
        async let a = work("a", ms: 50, log)
        async let b = work("b", ms: 10, log)
        log.add("start")
        log.add(await b)
        log.add(await a)
        return log.all
    }

    /// 4 — first result wins, then cancelAll.
    @MainActor public static func puzzle4() async -> [String] {
        let log = EventLog()
        let cancelled = CallCounter()
        await withTaskGroup(of: Void.self) { group in
            for ms in [10, 40, 60] {
                group.addTask {
                    do {
                        try await Task.sleep(for: .milliseconds(ms))
                        log.add("\(ms) done")
                    } catch {
                        cancelled.increment()
                    }
                }
            }
            await group.next()
            group.cancelAll()
        }
        log.add("cancelled: \(cancelled.count)")
        return log.all
    }

    /// 5 — bufferingOldest(2), nobody reading until the end.
    @MainActor public static func puzzle5() async -> [String] {
        let (stream, continuation) = AsyncStream.makeStream(of: Int.self, bufferingPolicy: .bufferingOldest(2))
        for i in 1...5 { continuation.yield(i) }
        continuation.finish()
        var out: [String] = []
        for await v in stream { out.append("\(v)") }
        return out
    }

    /// 6 — a cancellation handler on a task nobody cancels.
    @MainActor public static func puzzle6() async -> [String] {
        let log = EventLog()
        await withTaskCancellationHandler {
            log.add("operation")
        } onCancel: {
            log.add("onCancel")
        }
        log.add("after")
        return log.all
    }

    /// 7 — an un-awaited async let whose child ignores cancellation.
    static func stubborn(_ log: EventLog) async {
        await withCheckedContinuation { (c: CheckedContinuation<Void, Never>) in
            DispatchQueue.global().asyncAfter(deadline: .now() + .milliseconds(30)) { c.resume() }
        }
        log.add("stubborn done")
    }

    static func scope(_ log: EventLog) async {
        async let _ = stubborn(log)
        log.add("body")
    }

    @MainActor public static func puzzle7() async -> [String] {
        let log = EventLog()
        await scope(log)
        log.add("after")
        return log.all
    }

    /// 8 — inside an actor: a plain async func vs a @concurrent func. Which isolation does each report?
    actor Vault {
        func check() async -> [String] {
            let plain = await Self.plainLabel()
            let concurrent = await Self.concurrentLabel()
            return [plain, concurrent]
        }
        static func plainLabel() async -> String { isolationLabel() }
        @concurrent static func concurrentLabel() async -> String { isolationLabel() }
    }

    @MainActor public static func puzzle8() async -> [String] {
        await Vault().check()
    }

    /// 9 — five Task { @MainActor in } created from NONISOLATED code.
    @MainActor public static func puzzle9() async -> [String] {
        let log = EventLog()
        await Task.detached {
            var tasks: [Task<Void, Never>] = []
            for i in 0..<5 { tasks.append(Task { @MainActor in log.add("\(i)") }) }
            for t in tasks { await t.value }
        }.value
        return log.all
    }

    /// 10 — a throwing group consumed with `for try await`.
    struct Boom: Error {}

    @MainActor public static func puzzle10() async -> [String] {
        let log = EventLog()
        do {
            try await withThrowingTaskGroup(of: Void.self) { group in
                group.addTask {
                    try await Task.sleep(for: .milliseconds(10))
                    throw Boom()
                }
                group.addTask {
                    do { try await Task.sleep(for: .milliseconds(300)); log.add("slow done") } catch { log.add("slow cancelled") }
                }
                for try await _ in group {}
            }
        } catch {
            log.add("caught")
        }
        return log.all
    }
}
