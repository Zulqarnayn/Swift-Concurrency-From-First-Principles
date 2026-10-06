import LabKit

// P3.12 — "What does this print?" for structured concurrency and cancellation.
// Predict in Exercises/P3_12_Predictions.swift, then:  swift test --filter P3_12   /   swift run lab p3.12

public enum StructuredPuzzles {
    public static let all: [(String, @MainActor () async -> [String])] = [
        ("puzzle1", puzzle1), ("puzzle2", puzzle2), ("puzzle3", puzzle3),
        ("puzzle4", puzzle4), ("puzzle5", puzzle5), ("puzzle6", puzzle6),
    ]

    static func child(_ name: String, ms: Int, _ log: EventLog) async {
        do {
            try await Task.sleep(for: .milliseconds(ms))
            log.add("\(name) done")
        } catch {
            log.add("\(name) cancelled")
        }
    }

    // MARK: Puzzle 1 — an async let nobody awaits

    static func scope(_ log: EventLog) async {
        async let _ = child("child", ms: 200, log)
        log.add("body")
    }

    @MainActor
    public static func puzzle1() async -> [String] {
        let log = EventLog()
        await scope(log)
        log.add("after scope")
        return log.all
    }

    // MARK: Puzzle 2 — TaskGroup result order

    @MainActor
    public static func puzzle2() async -> [String] {
        await withTaskGroup(of: String.self) { group in
            group.addTask { try? await Task.sleep(for: .milliseconds(60)); return "A" }
            group.addTask { try? await Task.sleep(for: .milliseconds(10)); return "B" }
            group.addTask { try? await Task.sleep(for: .milliseconds(35)); return "C" }
            var order: [String] = []
            for await name in group { order.append(name) }
            return order
        }
    }

    // MARK: Puzzle 3 — a child throws inside a ThrowingTaskGroup

    struct Boom: Error {}

    @MainActor
    public static func puzzle3() async -> [String] {
        let log = EventLog()
        do {
            try await withThrowingTaskGroup(of: Void.self) { group in
                group.addTask {
                    try await Task.sleep(for: .milliseconds(10))
                    throw Boom()
                }
                group.addTask { await child("slow", ms: 300, log) }
                try await group.waitForAll()
            }
        } catch {
            log.add("caught")
        }
        return log.all
    }

    // MARK: Puzzle 4 — cancel a parent that has an async let child and a Task {} child

    @MainActor
    public static func puzzle4() async -> [String] {
        let log = EventLog()
        let parent = Task {
            Task { await child("Task{}", ms: 80, log) }
            async let structured: Void = child("async let", ms: 80, log)
            await structured
        }
        await suspend(ms: 20)
        parent.cancel()
        await parent.value
        await suspend(ms: 120)
        return log.all
    }

    // MARK: Puzzle 5 — withTaskCancellationHandler on an already-cancelled task

    @MainActor
    public static func puzzle5() async -> [String] {
        let log = EventLog()
        let task = Task {
            await withTaskCancellationHandler {
                log.add("operation")
            } onCancel: {
                log.add("onCancel")
            }
        }
        task.cancel()
        await task.value
        return log.all
    }

    // MARK: Puzzle 6 — task-local values

    enum Context {
        @TaskLocal static var user = "anonymous"
    }

    @MainActor
    public static func puzzle6() async -> [String] {
        await Context.$user.withValue("ada") {
            let inTask = await Task { Context.user }.value
            let inDetached = await Task.detached { Context.user }.value
            async let inAsyncLet = Context.user
            return [inTask, inDetached, await inAsyncLet]
        } + [Context.user]
    }
}
