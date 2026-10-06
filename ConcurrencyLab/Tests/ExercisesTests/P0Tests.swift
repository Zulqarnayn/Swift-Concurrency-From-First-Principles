import Dispatch
import Exercises
import Foundation
import LabKit
import Puzzles
import Synchronization
import Testing

@Suite struct P0_01Tests {
    @Test func wallTime() {
        #expect(P0_01.wallTimeMs(tasks: 8, taskMs: 100, cores: 4) == 200)
        #expect(P0_01.wallTimeMs(tasks: 9, taskMs: 100, cores: 4) == 300) // a leftover task needs a whole extra round
        #expect(P0_01.wallTimeMs(tasks: 3, taskMs: 50, cores: 8) == 50)   // idle cores don't help
        #expect(P0_01.wallTimeMs(tasks: 0, taskMs: 50, cores: 8) == 0)
    }

    @Test func amdahl() {
        #expect(abs(P0_01.amdahlSpeedup(parallelFraction: 0.5, cores: 2) - 4.0 / 3.0) < 0.001)
        #expect(abs(P0_01.amdahlSpeedup(parallelFraction: 1.0, cores: 8) - 8.0) < 0.001)
        #expect(abs(P0_01.amdahlSpeedup(parallelFraction: 0.0, cores: 8) - 1.0) < 0.001)
        // 95% parallel, (practically) infinite cores → capped at 20×. The serial 5% dominates.
        #expect(abs(P0_01.amdahlSpeedup(parallelFraction: 0.95, cores: 1_000_000) - 20.0) < 0.01)
    }
}

@Suite struct P0_02Tests {
    static let threads = 8
    static let increments = 20_000

    @Test func queueCounterIsExact() async {
        let counter = QueueCounter()
        await onDedicatedThread {
            onThreads(Self.threads) { _ in
                for _ in 0..<Self.increments { counter.increment() }
            }
        }
        #expect(counter.current == Self.threads * Self.increments)
    }

    @Test func lockCounterIsExact() async {
        let counter = LockCounter()
        await onDedicatedThread {
            onThreads(Self.threads) { _ in
                for _ in 0..<Self.increments { counter.increment() }
            }
        }
        #expect(counter.current == Self.threads * Self.increments)
    }
}

@Suite struct P0_03Tests {
    @Test func neverExceedsLimit() async {
        for _ in 0..<5 {
            let counter = BoundedCounter(limit: 1_000)
            let successes = CallCounter()
            await onDedicatedThread {
                onThreads(8) { _ in
                    for _ in 0..<2_000 where counter.tryIncrement() {
                        successes.increment()
                    }
                }
            }
            #expect(counter.current == 1_000)
            #expect(successes.count == 1_000, "every `true` must correspond to exactly one increment")
        }
    }
}

@Suite struct P0_04Tests {
    @Test func neverOverdraws() async {
        let account = BankAccount(balance: 500)
        let approved = CallCounter()
        await onDedicatedThread {
            onThreads(20) { _ in
                for _ in 0..<5 where account.withdraw(10) {
                    approved.increment()
                }
            }
        }
        #expect(approved.count == 50)
        #expect(account.current == 0)
    }
}

@Suite struct P0_05Tests {
    @Test func opposingTransfersDoNotDeadlock() async {
        let a = LockedAccount(id: 1, balance: 1_000)
        let b = LockedAccount(id: 2, balance: 1_000)
        let finished = await onDedicatedThread(timeoutSeconds: 5) {
            onThreads(2) { i in
                for _ in 0..<500 {
                    if i == 0 { P0_05.transfer(from: a, to: b, amount: 1) }
                    else { P0_05.transfer(from: b, to: a, amount: 1) }
                }
            }
            return true
        }
        #expect(finished == true, "deadlocked: no progress for 5 seconds")
        if finished == true {
            #expect(a.balance + b.balance == 2_000, "money was created or destroyed")
        }
    }
}

@Suite struct P0_06Tests {
    @Test func respectsLimit() async {
        let meter = ConcurrencyMeter()
        let done = CallCounter()
        let jobs: [@Sendable () -> Void] = (0..<30).map { _ in
            {
                meter.enter()
                blockThread(ms: 10)
                meter.leave()
                done.increment()
            }
        }
        await onDedicatedThread { P0_06.runAll(jobs, limit: 3) }
        #expect(done.count == 30, "runAll must return only after every job finished")
        #expect(meter.peak <= 3, "peak concurrency was \(meter.peak)")
        #expect(meter.peak == 3, "limit 3 should actually allow 3 at once (peak was \(meter.peak))")
    }
}

@Suite struct P0_07Tests {
    struct Outcome {
        let calls: Int
        let allOnCallbackQueue: Bool
        let first: Result<Profile, ProfileError>?
    }

    func load(_ id: String) async -> Outcome {
        await onDedicatedThread { Self.loadBlocking(id) }!
    }

    static func loadBlocking(_ id: String) -> Outcome {
        let queue = DispatchQueue(label: "test.callback")
        let calls = CallCounter()
        let onQueue = Mutex(true)
        let first = Mutex<Result<Profile, ProfileError>?>(nil)
        let firstCall = DispatchSemaphore(value: 0)

        P0_07.loadProfile(id: id, callbackQueue: queue) { result in
            calls.increment()
            if currentQueueLabel() != "test.callback" { onQueue.withLock { $0 = false } }
            first.withLock { if $0 == nil { $0 = result } }
            firstCall.signal()
        }
        _ = firstCall.wait(timeout: .now() + 1)
        usleep(150_000) // give a buggy implementation time to call a second time
        return Outcome(calls: calls.count, allOnCallbackQueue: onQueue.withLock { $0 }, first: first.withLock { $0 })
    }

    @Test func success() async {
        let o = await load("42")
        #expect(o.calls == 1)
        #expect(o.allOnCallbackQueue)
        #expect(o.first == .success(Profile(id: "42", name: "Name-42")))
    }

    @Test func emptyID() async {
        let o = await load("")
        #expect(o.calls == 1, "never calling completion = caller waits forever")
        #expect(o.allOnCallbackQueue)
        #expect(o.first == .failure(.invalidID))
    }

    @Test func networkError() async {
        let o = await load("offline-7")
        #expect(o.calls == 1, "calling completion twice = caller's continuation runs twice")
        #expect(o.allOnCallbackQueue)
        #expect(o.first == .failure(.network))
    }
}

@Suite struct P0_08Tests {
    @Test func puzzle1() async { #expect(P0_08.puzzle1 == (await onDedicatedThread { GCDPuzzles.puzzle1() })) }
    @Test func puzzle2() async { #expect(P0_08.puzzle2 == (await onDedicatedThread { GCDPuzzles.puzzle2() })) }
    @Test func puzzle3() async { #expect(P0_08.puzzle3 == (await onDedicatedThread { GCDPuzzles.puzzle3() })) }
    @Test func puzzle4() async { #expect(P0_08.puzzle4 == (await onDedicatedThread { GCDPuzzles.puzzle4() })) }
    @Test func puzzle5() async { #expect(P0_08.puzzle5 == (await onDedicatedThread { GCDPuzzles.puzzle5() })) }
}
