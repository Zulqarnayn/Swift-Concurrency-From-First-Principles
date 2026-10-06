import LabKit

// P3.11 — Unstructured tasks: start order and Task.immediate
// Lesson: lessons/P3-structured/11-unstructured-tasks.md
// Test:   swift test --filter P3_11

@MainActor
public final class LikeButtonModel {
    public private(set) var events: [String] = []
    public private(set) var isLiked = false

    public init() {}

    /// A synchronous UIKit-style tap handler.
    /// Requirement: the async work must START (record "like-started" and flip `isLiked`) before
    /// `tap()` returns — analytics depends on that order, and the UI must update in the same frame.
    ///
    /// BUG: `Task {}` only enqueues the work; it starts after `tap()` returns.
    /// TODO: start it synchronously, up to its first suspension point.
    public func tap() {
        Task {
            events.append("like-started")
            isLiked = true
            await suspend(ms: 20) // the network call
            events.append("like-confirmed")
        }
        events.append("tap-returned")
    }
}
