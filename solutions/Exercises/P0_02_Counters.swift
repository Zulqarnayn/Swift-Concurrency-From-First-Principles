import Foundation

// P0.02 — SOLUTION

public final class QueueCounter: @unchecked Sendable {
    private var value = 0
    // Serial queue = one block at a time = mutual exclusion.
    // `sync` for writes too (not `async`), so `current` read right after `increment()` sees it.
    // (`async` writes + `sync` reads is also correct and lets writers not wait — a classic variant.)
    private let queue = DispatchQueue(label: "QueueCounter")

    public init() {}

    public func increment() {
        queue.sync { value += 1 }
    }

    public var current: Int {
        queue.sync { value }
    }
}

public final class LockCounter: @unchecked Sendable {
    private var value = 0
    private let lock = NSLock()

    public init() {}

    public func increment() {
        lock.lock()
        defer { lock.unlock() }
        value += 1
    }

    public var current: Int {
        // Reads need the lock too: without it, a read may race a write (and on some
        // architectures/values could see a torn or stale value). "Only writes need locking" is a myth.
        lock.lock()
        defer { lock.unlock() }
        return value
    }
}
