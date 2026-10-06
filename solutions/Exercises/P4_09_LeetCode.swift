import LabKit

// P4.09 — SOLUTION. The LeetCode concurrency set, in async Swift
// Lesson: lessons/P4-classics/09-leetcode-set.md
// Test:   swift test --filter P4_09
//
// LeetCode's versions use threads + semaphores/locks. Here: actors + continuations. No polling, no
// sleeping, no blocking. Each `print` closure must be called by the method it belongs to.

/// LC 1114 "Print in Order". Three tasks call first/second/third concurrently, in ANY order.
/// Output must always be: first, second, third.
/// BUG: no coordination. TODO.
public actor InOrder {
    private var step = 1 // which method may print next
    private var waiting: [Int: CheckedContinuation<Void, Never>] = [:]

    public init() {}

    public func first(_ print: @Sendable () -> Void) async { await run(1, print) }
    public func second(_ print: @Sendable () -> Void) async { await run(2, print) }
    public func third(_ print: @Sendable () -> Void) async { await run(3, print) }

    private func run(_ myStep: Int, _ print: @Sendable () -> Void) async {
        if step != myStep {
            await withCheckedContinuation { waiting[myStep] = $0 } // park until it's my turn
        }
        print()
        step = myStep + 1
        waiting.removeValue(forKey: step)?.resume() // wake the next one if it's already waiting
    }
}

/// LC 1115 "Print FooBar Alternately". One task calls `foo`, another calls `bar`, concurrently.
/// Each loops `n` times. Output must be foo, bar, foo, bar, ...
/// BUG: no coordination. TODO.
public actor FooBar {
    public let n: Int
    private var fooTurn = true
    private var parked: CheckedContinuation<Void, Never>? // at most one side waits at a time
    public init(n: Int) { self.n = n }

    public func foo(_ printFoo: @Sendable () -> Void) async {
        for _ in 0..<n {
            while !fooTurn { await withCheckedContinuation { parked = $0 } }
            printFoo()
            fooTurn = false
            handOver()
        }
    }

    public func bar(_ printBar: @Sendable () -> Void) async {
        for _ in 0..<n {
            while fooTurn { await withCheckedContinuation { parked = $0 } }
            printBar()
            fooTurn = true
            handOver()
        }
    }

    private func handOver() {
        let other = parked
        parked = nil
        other?.resume()
    }
    // Why this works: an actor is reentrant at `await`. When foo parks, the actor is free,
    // so bar can run, flip the turn, and resume foo. A lock-based version would need two semaphores.
}

/// LC 1117 "Building H2O". Many tasks call `hydrogen` or `oxygen` concurrently, in any order.
/// Releases must come in complete molecules: every consecutive group of 3 = 2 H + 1 O.
/// Each call must not return until its atom has been released (as part of a molecule).
/// BUG: releases immediately. TODO.
public actor H2O {
    private typealias Atom = (release: @Sendable () -> Void, continuation: CheckedContinuation<Void, Never>)
    private var hydrogens: [Atom] = []
    private var oxygens: [Atom] = []

    public init() {}

    public func hydrogen(_ releaseHydrogen: @escaping @Sendable () -> Void) async {
        await withCheckedContinuation { hydrogens.append((releaseHydrogen, $0)); bond() }
    }

    public func oxygen(_ releaseOxygen: @escaping @Sendable () -> Void) async {
        await withCheckedContinuation { oxygens.append((releaseOxygen, $0)); bond() }
    }

    /// Whenever 2 H + 1 O are waiting, release them as ONE molecule. The three release calls happen
    /// synchronously on the actor, back to back, so no other atom can interleave inside a molecule.
    private func bond() {
        while hydrogens.count >= 2 && !oxygens.isEmpty {
            let molecule = [hydrogens.removeFirst(), hydrogens.removeFirst(), oxygens.removeFirst()]
            for atom in molecule { atom.release() }
            for atom in molecule { atom.continuation.resume() }
        }
    }
}
