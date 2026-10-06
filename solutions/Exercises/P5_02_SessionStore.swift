import Foundation
import LabKit

// P5.02 — SOLUTION. Bug hunt: "rare EXC_BAD_ACCESS crashes in SessionStore" (tests pass!)
// Lesson: lessons/P5-bug-zoo/02-tools.md
// Test:   swift test --filter P5_02         Hunt:  scripts/stress.sh P5_02 10 --tsan

/// Used from many threads (networking callbacks, background refresh, UI). Documented as thread-safe.
public final class SessionStore: @unchecked Sendable {
    private let lock = NSLock()
    private var sessions: [String: Int] = [:]
    private var activeUsers = 0
    private var lastActivity = Date.distantPast

    public init() {}

    public func login(_ user: String) {
        lock.withLock {
            if sessions[user] == nil { activeUsers += 1 }
            sessions[user, default: 0] += 1
            lastActivity = Date() // ROOT CAUSE #1: this write was outside the lock
        }
    }

    public func logout(_ user: String) {
        lock.withLock {
            if sessions.removeValue(forKey: user) != nil { activeUsers -= 1 }
        }
    }

    // ROOT CAUSE #2: reads were unlocked. "Reads don't need the lock" is a myth (P0.02): a read racing a
    // write is a data race. With a Date (16 bytes) a reader can even see a torn value.
    public var activeCount: Int {
        lock.withLock { activeUsers }
    }

    public var secondsSinceLastActivity: Double {
        let last = lock.withLock { lastActivity }
        return Date().timeIntervalSince(last)
    }

    public func isLoggedIn(_ user: String) -> Bool {
        lock.withLock { sessions[user] != nil }
    }
}
