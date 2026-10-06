import LabKit

// P4.09 — The LeetCode concurrency set, in async Swift
// Lesson: lessons/P4-classics/09-leetcode-set.md
// Test:   swift test --filter P4_09
//
// LeetCode's versions use threads + semaphores/locks. Here: actors + continuations. No polling, no
// sleeping, no blocking. Each `print` closure must be called by the method it belongs to.

/// LC 1114 "Print in Order". Three tasks call first/second/third concurrently, in ANY order.
/// Output must always be: first, second, third.
/// BUG: no coordination. TODO.
public actor InOrder {
    public init() {}

    public func first(_ print: @Sendable () -> Void) async { print() }
    public func second(_ print: @Sendable () -> Void) async { print() }
    public func third(_ print: @Sendable () -> Void) async { print() }
}

/// LC 1115 "Print FooBar Alternately". One task calls `foo`, another calls `bar`, concurrently.
/// Each loops `n` times. Output must be foo, bar, foo, bar, ...
/// BUG: no coordination. TODO.
public actor FooBar {
    public let n: Int
    public init(n: Int) { self.n = n }

    public func foo(_ printFoo: @Sendable () -> Void) async {
        for _ in 0..<n { printFoo() }
    }

    public func bar(_ printBar: @Sendable () -> Void) async {
        for _ in 0..<n { printBar() }
    }
}

/// LC 1117 "Building H2O". Many tasks call `hydrogen` or `oxygen` concurrently, in any order.
/// Releases must come in complete molecules: every consecutive group of 3 = 2 H + 1 O.
/// Each call must not return until its atom has been released (as part of a molecule).
/// BUG: releases immediately. TODO.
public actor H2O {
    public init() {}

    public func hydrogen(_ releaseHydrogen: @escaping @Sendable () -> Void) async { releaseHydrogen() }
    public func oxygen(_ releaseOxygen: @escaping @Sendable () -> Void) async { releaseOxygen() }
}
