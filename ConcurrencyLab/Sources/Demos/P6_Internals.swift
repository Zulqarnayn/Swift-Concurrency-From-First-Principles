import Dispatch
import Distributed
import Foundation
import LabKit
import Puzzles
import Synchronization

let phase6: [Demo] = [
    Demo("p6.01", "A custom actor executor: an actor that lives on a DispatchQueue", p6_01),
    Demo("p6.02", "Task executor preference: steering nonisolated work", p6_02),
    Demo("p6.03", "What tasks cost: memory and time vs threads", p6_03),
    Demo("p6.04", "Hop costs: MainActor round trips vs actor calls vs batching", p6_04),
    Demo("p6.05", "A memory-ordering litmus test (and why 0 proves nothing)", p6_05),
    Demo("p6.06", "@isolated(any): Task { @MainActor in } keeps order, Task { await … } doesn't", p6_06),
    Demo("p6.08", "Distributed actors: the same actor, 'remote' through an actor system", p6_08),
]

let phase7: [Demo] = [
    Demo("p7.02", "Explain-the-output marathon (answers)", p7_02),
]

// MARK: - P6.01

/// A "legacy" component that must be touched only on its own queue.
actor QueueActor {
    let queue = DispatchSerialQueue(label: "demo.legacy.queue")
    nonisolated var unownedExecutor: UnownedSerialExecutor { queue.asUnownedSerialExecutor() }
    var events: [String] = []

    func record(_ event: String) -> String {
        events.append(event)
        return currentQueueLabel()
    }
}

@concurrent
func p6_01() async {
    let actor = QueueActor()
    let where1 = await actor.record("from async code")
    trace("actor method ran on queue: '\(where1)'")
    await withCheckedContinuation { (done: CheckedContinuation<Void, Never>) in
        actor.queue.async {
            // Old code already on the queue can enter the actor SYNCHRONOUSLY — no await, no hop:
            actor.assumeIsolated { isolated in
                _ = isolated.record("from legacy queue.async code")
            }
            done.resume()
        }
    }
    let count = await actor.events.count
    trace("legacy callback used assumeIsolated on the same queue → events: \(count)")
}

// MARK: - P6.02

final class LabeledQueueExecutor: TaskExecutor, @unchecked Sendable {
    let queue = DispatchQueue(label: "demo.task.executor")
    func enqueue(_ job: consuming ExecutorJob) {
        let job = UnownedJob(job)
        queue.async { job.runSynchronously(on: self.asUnownedTaskExecutor()) }
    }
}

@concurrent func whereConcurrent() async -> String { currentQueueLabel() }
func wherePlain() async -> String { currentQueueLabel() }

@concurrent
func p6_02() async {
    let executor = LabeledQueueExecutor()
    let plainRun = await whereConcurrent()
    trace("without preference, @concurrent runs on: '\(plainRun)'")
    let a = await withTaskExecutorPreference(executor) { await whereConcurrent() }
    let b = await withTaskExecutorPreference(executor) { await wherePlain() }
    let c = await withTaskExecutorPreference(executor) {
        await withTaskGroup(of: String.self) { g in
            g.addTask { currentQueueLabel() }
            return await g.next()!
        }
    }
    trace("with preference: @concurrent → '\(a)', plain async → '\(b)', group child → '\(c)'")
    let actorLabel = await withTaskExecutorPreference(executor) { await QueueActor().record("x") }
    trace("but an ACTOR keeps its own executor even under a preference → '\(actorLabel)'")
}

// MARK: - P6.03

func residentBytes() -> Int {
    var info = mach_task_basic_info()
    var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size / MemoryLayout<natural_t>.size)
    _ = withUnsafeMutablePointer(to: &info) {
        $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
            task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
        }
    }
    return Int(info.resident_size)
}

final class ContinuationGate: Sendable {
    private let waiting = Mutex<[CheckedContinuation<Void, Never>]>([])
    func wait() async { await withCheckedContinuation { c in waiting.withLock { $0.append(c) } } }
    func openAll() {
        let all = waiting.withLock { w in defer { w = [] }; return w }
        for c in all { c.resume() }
    }
}

@concurrent
func p6_03() async {
    let n = 50_000
    let gate = ContinuationGate()
    let before = residentBytes()
    var tasks: [Task<Void, Never>] = []
    for _ in 0..<n { tasks.append(Task { await gate.wait() }) }
    await suspend(ms: 400)
    let perTask = (residentBytes() - before) / n
    trace("\(n) SUSPENDED tasks: ≈ \(perTask) bytes each (resident)")
    gate.openAll()
    for t in tasks { await t.value }

    let threadsBefore = residentBytes()
    let release = DispatchSemaphore(value: 0)
    for _ in 0..<500 { Thread.detachNewThread { release.wait() } }
    await suspend(ms: 400)
    let perThread = (residentBytes() - threadsBefore) / 500
    trace("500 BLOCKED threads: ≈ \(perThread) bytes each resident, plus 512KB of reserved stack each")
    for _ in 0..<500 { release.signal() }

    let k = 20_000
    let createMs = await measureMs { for _ in 0..<k { await Task {}.value } }
    trace("Task { } create + await: ≈ \(String(format: "%.2f", Double(createMs) * 1000 / Double(k)))µs each (debug build)")
}

// MARK: - P6.04

actor PlainCounter {
    var n = 0
    func increment() { n += 1 }
    func increment(by k: Int) { n += k }
}

@MainActor var mainTicks = 0
@MainActor func mainTick() { mainTicks += 1 }

@concurrent
func p6_04() async {
    let k = 10_000
    let mainMs = await measureMs { for _ in 0..<k { await mainTick() } }
    trace("\(k) round trips pool → MainActor → back: \(mainMs)ms (≈ \(String(format: "%.1f", Double(mainMs) * 1000 / Double(k)))µs each — a real thread switch)")
    let counter = PlainCounter()
    let actorMs = await measureMs { for _ in 0..<k { await counter.increment() } }
    trace("\(k) calls pool → idle actor: \(actorMs)ms (the runtime can run the actor right on this thread)")
    let batchMs = await measureMs { await counter.increment(by: k) }
    trace("1 call carrying all \(k) updates: \(batchMs)ms")
}

// MARK: - P6.05

@concurrent
func p6_05() async {
    let result = await onDedicatedThread { () -> Int in
        let data = Atomic<Int>(0)
        let flag = Atomic<Int>(0)
        let seen = Atomic<Int>(-1)
        var weird = 0
        for _ in 0..<100_000 {
            data.store(0, ordering: .relaxed)
            flag.store(0, ordering: .relaxed)
            let group = DispatchGroup()
            DispatchQueue.global().async(group: group) {
                data.store(1, ordering: .relaxed)
                flag.store(1, ordering: .relaxed)
            }
            DispatchQueue.global().async(group: group) {
                while flag.load(ordering: .relaxed) == 0 {}
                seen.store(data.load(ordering: .relaxed), ordering: .relaxed)
            }
            group.wait()
            if seen.load(ordering: .relaxed) == 0 { weird += 1 }
        }
        return weird
    }!
    trace("message-passing litmus with RELAXED atomics: saw flag == 1 but data == 0 in \(result) / 100000 runs")
    trace("The model ALLOWS that outcome; this hardware/run didn't show it. Correctness = what's guaranteed, not what you saw.")
}

// MARK: - P6.06

@MainActor final class OrderLog {
    var items: [Int] = []
    func add(_ i: Int) { items.append(i) }
}

@concurrent
func p6_06() async {
    var isolatedClosureOK = 0
    var hoppingClosureOK = 0
    for _ in 0..<20 {
        let a = OrderLog() // a @MainActor class's synthesized init is nonisolated: no hop needed
        let b = OrderLog()
        var tasks: [Task<Void, Never>] = []
        for i in 0..<10 { tasks.append(Task { @MainActor in a.add(i) }) }   // @isolated(any) closure IS main-isolated
        for i in 0..<10 { tasks.append(Task { await b.add(i) }) }           // nonisolated closure that hops later
        for t in tasks { await t.value }
        if await a.items == Array(0..<10) { isolatedClosureOK += 1 }
        if await b.items == Array(0..<10) { hoppingClosureOK += 1 }
    }
    trace("from nonisolated code, 10 tasks each, 20 rounds — kept creation order:")
    trace("  Task { @MainActor in log.add(i) }   → \(isolatedClosureOK)/20 rounds")
    trace("  Task { await log.add(i) }           → \(hoppingClosureOK)/20 rounds")
    let f: @isolated(any) () async -> Void = { @MainActor in }
    trace("an @isolated(any) function value carries its isolation: f.isolation = \(f.isolation.map { "\(type(of: $0))" } ?? "nil")")
}

// MARK: - P6.08

distributed actor DemoGreeter {
    typealias ActorSystem = LocalTestingDistributedActorSystem
    var greeted = 0
    distributed func greet(_ name: String) -> String {
        greeted += 1
        return "hello \(name) (#\(greeted))"
    }
}

@concurrent
func p6_08() async {
    let system = LocalTestingDistributedActorSystem()
    let greeter = DemoGreeter(actorSystem: system)
    trace("created \(greeter.id)")
    do {
        let viaRef = try await greeter.greet("ada")
        let resolved = try DemoGreeter.resolve(id: greeter.id, using: system) // what another node would do
        let viaID = try await resolved.greet("linus")
        trace("direct: \(viaRef) · resolved by id: \(viaID)")
        trace("every distributed call is `try await`: on a real system it may cross a network and fail")
    } catch {
        trace("error: \(error)")
    }
}

// MARK: - P7.02

func p7_02() async {
    for (name, run) in MarathonPuzzles.all {
        let answer = await run()
        trace("\(name): \(answer)")
    }
}
