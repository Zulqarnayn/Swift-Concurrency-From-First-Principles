import LabKit

// P2.16 — "What does this print?" for isolation and actors.
// Predict in Exercises/P2_16_Predictions.swift, then:  swift test --filter P2_16   /   swift run lab p2.16

public enum IsolationPuzzles {
    public static let all: [(String, @MainActor () async -> [String])] = [
        ("puzzle1", puzzle1), ("puzzle2", puzzle2), ("puzzle3", puzzle3),
        ("puzzle4", puzzle4), ("puzzle5", puzzle5), ("puzzle6", puzzle6),
    ]

    // MARK: Puzzle 1 — does an actor run one call at a time, start to finish?

    actor Worker {
        let log: EventLog
        init(log: EventLog) { self.log = log }
        func work(_ id: Int, ms: Int) async {
            log.add("\(id) start")
            await suspend(ms: ms)
            log.add("\(id) end")
        }
    }

    @MainActor
    public static func puzzle1() async -> [String] {
        let log = EventLog()
        let worker = Worker(log: log)
        let t1 = Task { await worker.work(1, ms: 60) }
        await suspend(ms: 5)
        let t2 = Task { await worker.work(2, ms: 10) }
        await t1.value
        await t2.value
        return log.all
    }

    // MARK: Puzzle 2 — balance 100, two concurrent withdrawals of 80, with an await in the middle

    actor Account {
        var balance = 100
        func withdraw(_ amount: Int) async -> Bool {
            guard balance >= amount else { return false }
            await suspend(ms: 20) // fraud check
            balance -= amount
            return true
        }
    }

    @MainActor
    public static func puzzle2() async -> [String] {
        let account = Account()
        async let a = account.withdraw(80)
        async let b = account.withdraw(80)
        let approved = await [a, b].filter { $0 }.count
        let balance = await account.balance
        return ["approved: \(approved)", "balance: \(balance)"]
    }

    // MARK: Puzzle 3 — a Task created inside an actor method (capturing self)

    actor Journal {
        let log: EventLog
        init(log: EventLog) { self.log = log }
        func write() async {
            log.add("m1")
            let task = Task { self.log.add("task") }
            log.add("m2")
            await task.value
        }
    }

    @MainActor
    public static func puzzle3() async -> [String] {
        let log = EventLog()
        await Journal(log: log).write()
        return log.all
    }

    // MARK: Puzzle 4 — an actor awaiting its OWN async method

    actor Desk {
        let log: EventLog
        init(log: EventLog) { self.log = log }
        func helper() async { log.add("helper") }
        func work() async {
            log.add("a")
            let other = Task { self.log.add("other") }
            await helper()
            log.add("b")
            await other.value
        }
    }

    @MainActor
    public static func puzzle4() async -> [String] {
        let log = EventLog()
        await Desk(log: log).work()
        return log.all
    }

    // MARK: Puzzle 5 — main actor calls a plain (nonsending) async function

    static func plainWork(_ log: EventLog) async {
        log.add("plain")
    }

    @MainActor
    public static func puzzle5() async -> [String] {
        let log = EventLog()
        log.add("1")
        let task = Task { log.add("task") }
        await plainWork(log)
        log.add("2")
        await task.value
        return log.all
    }

    // MARK: Puzzle 6 — main actor calls a @concurrent function

    @concurrent static func concurrentWork() async {
        await suspend(ms: 20)
    }

    @MainActor
    public static func puzzle6() async -> [String] {
        let log = EventLog()
        log.add("1")
        let task = Task { log.add("task") }
        await concurrentWork()
        log.add("2")
        await task.value
        return log.all
    }
}
