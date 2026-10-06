import LabKit

// P6.06 — SOLUTION. @isolated(any): ordering when you hop to an actor
// Lesson: lessons/P6-internals/06-isolated-any.md
// Test:   swift test --filter P6_06

/// Receives live events on the main actor (don't edit).
@MainActor
public final class EventSink {
    public private(set) var events: [Int] = []
    public init() {}
    public func record(_ event: Int) { events.append(event) }
}

public enum P6_06 {
    /// Called synchronously, in order, from NONISOLATED code (a socket's callback thread).
    /// Every event must reach `sink` IN THE SAME ORDER. `forward` must stay synchronous.
    ///
    /// Without a serial stream (P1.08), and without making this async: what kind of Task enqueues its
    /// work on the main actor at the moment it's CREATED? (One small change.)
    public static func forward(_ event: Int, to sink: EventSink) {
        // `Task { @MainActor in … }`: the closure is ISOLATED to the main actor, and Task.init takes an
        // `@isolated(any)` closure — so the runtime knows its target and enqueues the task DIRECTLY on the
        // main actor's (FIFO) executor at creation time, in creation order (SE-0431).
        // The old version created a NONISOLATED task: it started on the global pool (no order guarantee)
        // and only then hopped to main — racing with its siblings.
        Task { @MainActor in
            sink.record(event)
        }
    }
}
