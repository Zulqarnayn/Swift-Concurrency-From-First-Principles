import Foundation

// P0.02 — Data races
// Lesson: lessons/P0-foundations/02-data-race.md
// Test:   swift test --filter P0_02
//
// Both counters are marked `@unchecked Sendable`. That tells the compiler:
// "Stop checking. I promise I synchronize every access myself."
// Right now that promise is a lie. Make it true — two different ways.

/// TODO: protect `value` with a private SERIAL DispatchQueue. Every read and write goes through `queue.sync`.
public final class QueueCounter: @unchecked Sendable {
    private var value = 0

    public init() {}

    public func increment() {
        value += 1
    }

    public var current: Int {
        value
    }
}

/// TODO: protect `value` with an NSLock. Every read and write happens between lock() and unlock().
public final class LockCounter: @unchecked Sendable {
    private var value = 0

    public init() {}

    public func increment() {
        value += 1
    }

    public var current: Int {
        value
    }
}
